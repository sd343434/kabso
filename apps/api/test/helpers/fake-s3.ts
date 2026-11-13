import { createHash } from 'node:crypto';
import { createServer, type IncomingMessage, type Server, type ServerResponse } from 'node:http';
import type { AddressInfo } from 'node:net';

/**
 * D222 (tests only): a tiny S3-compatible HTTP server for the production adapter (`S3ObjectStorage`, the real AWS SDK)
 * when no MinIO / moto is around (CI). Path-style only: PUT / GET (with Range) / HEAD / DELETE object, CopyObject
 * (`x-amz-copy-source`, also between buckets) and DeleteObjects (`POST ?delete`). Signed requests must name the access
 * key id the server was made with (the signature itself is not checked: that is S3's job, not ours); anonymous GETs
 * read only a bucket marked public — which is also how the "public base URL" of a bucket is served
 * (`<url>/<bucket>`). Not a full S3: just what the API and «اختبار الاتصال» use.
 */
export class FakeS3 {
  private server: Server | null = null;
  readonly buckets = new Map<string, { public: boolean; objects: Map<string, StoredObject> }>();
  /** Every request as `METHOD bucket/key` (`anon` when unsigned). */
  readonly log: string[] = [];
  /** Buckets whose signed requests are refused with AccessDenied (a token limited to other buckets). */
  readonly denied = new Set<string>();

  constructor(
    readonly accessKeyId: string,
    readonly secretAccessKey: string,
  ) {}

  get endpoint(): string {
    const port = (this.server?.address() as AddressInfo | null)?.port;
    return `http://127.0.0.1:${port}`;
  }

  /** What a CDN / R2 public URL of `bucket` would be. */
  publicUrl(bucket: string): string {
    return `${this.endpoint}/${bucket}`;
  }

  createBucket(name: string, isPublic: boolean): void {
    this.buckets.set(name, { public: isPublic, objects: new Map() });
  }

  keys(bucket: string): string[] {
    return [...(this.buckets.get(bucket)?.objects.keys() ?? [])].sort();
  }

  async start(): Promise<void> {
    this.server = createServer((req, res) => {
      const chunks: Buffer[] = [];
      req.on('data', (c: Buffer) => chunks.push(c));
      req.on('end', () => {
        try {
          this.handle(req, Buffer.concat(chunks), res);
        } catch (err) {
          send(res, 500, errorXml('InternalError', String(err)));
        }
      });
    });
    await new Promise<void>((resolve) => this.server!.listen(0, '127.0.0.1', resolve));
  }

  async stop(): Promise<void> {
    await new Promise<void>((resolve) => (this.server ? this.server.close(() => resolve()) : resolve()));
  }

  private handle(req: IncomingMessage, body: Buffer, res: ServerResponse): void {
    const url = new URL(req.url ?? '/', 'http://x');
    const [, bucketName = '', ...rest] = url.pathname.split('/');
    const key = decodeURIComponent(rest.join('/'));
    const method = req.method ?? 'GET';
    const auth = req.headers.authorization ?? url.searchParams.get('X-Amz-Credential') ?? null;
    const signed = auth !== null;
    this.log.push(`${method} ${bucketName}/${key}${signed ? '' : ' anon'}`);
    const head = method === 'HEAD';
    if (signed) {
      const credential = /Credential=([^/,]+)/.exec(auth)?.[1] ?? auth.split('/')[0];
      if (credential !== this.accessKeyId) {
        return send(
          res,
          403,
          head ? '' : errorXml('InvalidAccessKeyId', 'The AWS Access Key Id you provided does not exist.'),
        );
      }
    }
    const bucket = this.buckets.get(bucketName);
    if (!bucket)
      return send(res, 404, head ? '' : errorXml('NoSuchBucket', 'The specified bucket does not exist'));
    if (!signed && !(bucket.public && (method === 'GET' || head))) {
      return send(res, 403, head ? '' : errorXml('AccessDenied', 'Access Denied'));
    }
    if (signed && this.denied.has(bucketName))
      return send(res, 403, head ? '' : errorXml('AccessDenied', 'Access Denied'));

    if (method === 'POST' && url.searchParams.has('delete')) {
      for (const m of body.toString('utf8').matchAll(/<Key>([^<]*)<\/Key>/g))
        bucket.objects.delete(unxml(m[1]!));
      return send(res, 200, '<?xml version="1.0" encoding="UTF-8"?><DeleteResult></DeleteResult>');
    }
    if (method === 'PUT') {
      const source = req.headers['x-amz-copy-source'];
      if (typeof source === 'string') {
        const [srcBucket = '', ...srcKey] = decodeURIComponent(source.replace(/^\//, '')).split('/');
        const from = this.buckets.get(srcBucket)?.objects.get(srcKey.join('/'));
        if (!from) return send(res, 404, errorXml('NoSuchKey', 'The specified key does not exist.'));
        const copy = { ...from, contentType: String(req.headers['content-type'] ?? from.contentType) };
        bucket.objects.set(key, copy);
        return send(
          res,
          200,
          `<?xml version="1.0" encoding="UTF-8"?><CopyObjectResult><ETag>"${copy.etag}"</ETag><LastModified>${new Date().toISOString()}</LastModified></CopyObjectResult>`,
        );
      }
      const declared = req.headers['content-length'];
      if (declared !== undefined && Number(declared) !== body.length) {
        return send(res, 400, errorXml('IncompleteBody', 'length mismatch'));
      }
      const etag = createHash('md5').update(body).digest('hex');
      bucket.objects.set(key, {
        body,
        contentType: String(req.headers['content-type'] ?? 'application/octet-stream'),
        cacheControl: String(req.headers['cache-control'] ?? ''),
        etag,
      });
      res.setHeader('ETag', `"${etag}"`);
      return send(res, 200, '');
    }
    if (method === 'DELETE') {
      bucket.objects.delete(key);
      return send(res, 204, '');
    }
    if (method === 'GET' || head) {
      const obj = bucket.objects.get(key);
      if (!obj) return send(res, 404, head ? '' : errorXml('NoSuchKey', 'The specified key does not exist.'));
      res.setHeader('Content-Type', obj.contentType);
      res.setHeader('ETag', `"${obj.etag}"`);
      res.setHeader('Last-Modified', new Date().toUTCString());
      if (obj.cacheControl) res.setHeader('Cache-Control', obj.cacheControl);
      const range = /^bytes=(\d+)-(\d+)$/.exec(String(req.headers.range ?? ''));
      if (range && !head) {
        const start = Number(range[1]);
        const end = Math.min(Number(range[2]), obj.body.length - 1);
        const part = obj.body.subarray(start, end + 1);
        res.setHeader('Content-Range', `bytes ${start}-${end}/${obj.body.length}`);
        res.setHeader('Content-Length', String(part.length));
        res.writeHead(206);
        return void res.end(part);
      }
      res.setHeader('Content-Length', String(obj.body.length));
      res.writeHead(200);
      return void res.end(head ? undefined : obj.body);
    }
    return send(res, 405, errorXml('MethodNotAllowed', method));
  }
}

interface StoredObject {
  readonly body: Buffer;
  readonly contentType: string;
  readonly cacheControl: string;
  readonly etag: string;
}

function errorXml(code: string, message: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?><Error><Code>${code}</Code><Message>${message}</Message></Error>`;
}

function unxml(s: string): string {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

function send(res: ServerResponse, status: number, body: string): void {
  if (body) res.setHeader('Content-Type', 'application/xml');
  res.setHeader('Content-Length', String(Buffer.byteLength(body)));
  res.writeHead(status);
  res.end(body);
}
