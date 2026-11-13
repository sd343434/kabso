import { createPublicKey, verify as verifySignature, X509Certificate } from 'node:crypto';

/**
 * v1.110-social (D345, CONVENTIONS §10.144.3): verifies Apple's signed data (a StoreKit 2 transaction's JWS, an App Store
 * Server Notification v2's `signedPayload`) locally, with no call to Apple — the rules of Apple's own App Store Server
 * Library: ES256 over `header.payload`, the `x5c` chain leaf → intermediate → root where each is issued and signed by
 * the next and valid at the effective date, the leaf carrying Apple's receipt-signing OID and the intermediate Apple's
 * WWDR OID, and the root byte-equal to one of the roots the owner placed on the server (Apple Root CA – G3). No Nest
 * dependencies (shared by the service and the tests).
 */

/** The leaf's marker extension (Mac App Store / StoreKit receipt signing), DER-encoded OID 1.2.840.113635.100.6.11.1. */
const LEAF_OID = Buffer.from('060a2a864886f76364060b01', 'hex');
/** The intermediate's marker extension (Apple WWDR), DER-encoded OID 1.2.840.113635.100.6.2.1. */
const INTERMEDIATE_OID = Buffer.from('060a2a864886f76364060201', 'hex');

export class AppleJwsError extends Error {
  constructor(readonly issue: string) {
    super(`Apple signed data rejected: ${issue}`);
  }
}

/** Reads a certificate given as DER or PEM bytes. */
export function readCertificate(bytes: Buffer): X509Certificate {
  return new X509Certificate(bytes);
}

function b64urlJson(part: string): Record<string, unknown> {
  try {
    const value: unknown = JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));
    if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new Error('not an object');
    return value as Record<string, unknown>;
  } catch {
    throw new AppleJwsError('malformed');
  }
}

/** Whether `cert` contains the DER of an extension OID (Apple's markers are the only extensions with these values). */
function hasOid(cert: X509Certificate, oid: Buffer): boolean {
  return cert.raw.includes(oid);
}

function validAt(cert: X509Certificate, at: Date): boolean {
  return (
    new Date(cert.validFrom).getTime() <= at.getTime() && at.getTime() <= new Date(cert.validTo).getTime()
  );
}

/**
 * Verifies `jws` and returns its decoded payload. `roots` are the trusted Apple roots; `now` the clock. The effective
 * date is the payload's `signedDate` (milliseconds) when present, as Apple's library does without online checks.
 */
export function verifyAppleJws(
  jws: string,
  roots: readonly X509Certificate[],
  now: Date = new Date(),
): Record<string, unknown> {
  if (typeof jws !== 'string' || jws.length > 64_000) throw new AppleJwsError('malformed');
  const parts = jws.split('.');
  if (parts.length !== 3 || parts.some((p) => !/^[A-Za-z0-9_-]+$/.test(p)))
    throw new AppleJwsError('malformed');
  const [h, p, sig] = parts as [string, string, string];
  const header = b64urlJson(h);
  if (header.alg !== 'ES256') throw new AppleJwsError('alg');
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length !== 3 || !x5c.every((c) => typeof c === 'string')) {
    throw new AppleJwsError('x5c');
  }
  let chain: X509Certificate[];
  try {
    chain = x5c.map((c) => new X509Certificate(Buffer.from(c, 'base64')));
  } catch {
    throw new AppleJwsError('x5c');
  }
  const [leaf, intermediate, root] = chain as [X509Certificate, X509Certificate, X509Certificate];
  if (roots.length === 0 || !roots.some((r) => r.raw.equals(root.raw))) throw new AppleJwsError('root');
  if (!leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey))
    throw new AppleJwsError('chain');
  if (!intermediate.checkIssued(root) || !intermediate.verify(root.publicKey))
    throw new AppleJwsError('chain');
  if (!hasOid(leaf, LEAF_OID) || !hasOid(intermediate, INTERMEDIATE_OID)) throw new AppleJwsError('oid');
  const payload = b64urlJson(p);
  const signed = typeof payload.signedDate === 'number' ? new Date(payload.signedDate) : now;
  for (const cert of chain) if (!validAt(cert, signed)) throw new AppleJwsError('expired');
  const ok = verifySignature(
    'sha256',
    Buffer.from(`${h}.${p}`),
    {
      key: createPublicKey(leaf.publicKey.export({ type: 'spki', format: 'pem' })),
      dsaEncoding: 'ieee-p1363',
    },
    Buffer.from(sig, 'base64url'),
  );
  if (!ok) throw new AppleJwsError('signature');
  return payload;
}
