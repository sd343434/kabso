/**
 * v1.66-social (D198): a minimal ZIP writer (PKWARE APPNOTE 6.3, DEFLATE or STORED, UTF-8 names, no ZIP64) for the
 * personal-data export. Node's own zlib does the compression and the CRC-32; no dependency. Limits: < 65 535 entries
 * and < 4 GiB in all (the export is far smaller; `ZipWriter` throws instead of writing a broken archive).
 */
import { crc32, deflateRawSync } from 'node:zlib';

interface Entry {
  readonly name: Buffer;
  readonly crc: number;
  readonly size: number;
  readonly compressedSize: number;
  readonly method: 0 | 8;
  readonly offset: number;
  readonly dosTime: number;
  readonly dosDate: number;
}

const UTF8_FLAG = 0x0800;
const MAX_U32 = 0xffffffff;

function dosDateTime(at: Date): { dosTime: number; dosDate: number } {
  const y = Math.max(1980, at.getUTCFullYear());
  return {
    dosTime: (at.getUTCHours() << 11) | (at.getUTCMinutes() << 5) | Math.floor(at.getUTCSeconds() / 2),
    dosDate: ((y - 1980) << 9) | ((at.getUTCMonth() + 1) << 5) | at.getUTCDate(),
  };
}

/** Builds a ZIP in memory. Names are relative paths with `/` (no `..`, no leading `/`). */
export class ZipWriter {
  private readonly chunks: Buffer[] = [];
  private readonly entries: Entry[] = [];
  private offset = 0;
  private readonly names = new Set<string>();

  constructor(private readonly at: Date = new Date()) {}

  add(name: string, data: Buffer | string): void {
    if (!/^[^/\\][^\\]*$/.test(name) || name.split('/').some((p) => p === '..' || p === '' || p === '.')) {
      throw new Error(`zip: bad entry name ${name}`);
    }
    if (this.names.has(name)) throw new Error(`zip: duplicate entry ${name}`);
    if (this.entries.length >= 65_534) throw new Error('zip: too many entries');
    this.names.add(name);
    const bytes = typeof data === 'string' ? Buffer.from(data, 'utf8') : data;
    const deflated = deflateRawSync(bytes, { level: 6 });
    const useDeflate = deflated.length < bytes.length;
    const body = useDeflate ? deflated : bytes;
    const nameBytes = Buffer.from(name, 'utf8');
    const { dosTime, dosDate } = dosDateTime(this.at);
    const entry: Entry = {
      name: nameBytes,
      crc: crc32(bytes) >>> 0,
      size: bytes.length,
      compressedSize: body.length,
      method: useDeflate ? 8 : 0,
      offset: this.offset,
      dosTime,
      dosDate,
    };
    if (entry.offset + 30 + nameBytes.length + body.length > MAX_U32)
      throw new Error('zip: archive too large');
    const header = Buffer.alloc(30);
    header.writeUInt32LE(0x04034b50, 0);
    header.writeUInt16LE(20, 4); // version needed: 2.0
    header.writeUInt16LE(UTF8_FLAG, 6);
    header.writeUInt16LE(entry.method, 8);
    header.writeUInt16LE(dosTime, 10);
    header.writeUInt16LE(dosDate, 12);
    header.writeUInt32LE(entry.crc, 14);
    header.writeUInt32LE(entry.compressedSize, 18);
    header.writeUInt32LE(entry.size, 22);
    header.writeUInt16LE(nameBytes.length, 26);
    header.writeUInt16LE(0, 28);
    this.chunks.push(header, nameBytes, body);
    this.offset += header.length + nameBytes.length + body.length;
    this.entries.push(entry);
  }

  /** The finished archive (the writer must not be used afterwards). */
  finish(): Buffer {
    const central: Buffer[] = [];
    let centralSize = 0;
    for (const e of this.entries) {
      const h = Buffer.alloc(46);
      h.writeUInt32LE(0x02014b50, 0);
      h.writeUInt16LE(0x0314, 4); // made by: UNIX, 2.0
      h.writeUInt16LE(20, 6);
      h.writeUInt16LE(UTF8_FLAG, 8);
      h.writeUInt16LE(e.method, 10);
      h.writeUInt16LE(e.dosTime, 12);
      h.writeUInt16LE(e.dosDate, 14);
      h.writeUInt32LE(e.crc, 16);
      h.writeUInt32LE(e.compressedSize, 20);
      h.writeUInt32LE(e.size, 24);
      h.writeUInt16LE(e.name.length, 28);
      h.writeUInt16LE(0, 30); // extra
      h.writeUInt16LE(0, 32); // comment
      h.writeUInt16LE(0, 34); // disk
      h.writeUInt16LE(0, 36); // internal attributes
      h.writeUInt32LE((0o100644 << 16) >>> 0, 38); // -rw-r--r--
      h.writeUInt32LE(e.offset, 42);
      central.push(h, e.name);
      centralSize += h.length + e.name.length;
    }
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(this.entries.length, 8);
    end.writeUInt16LE(this.entries.length, 10);
    end.writeUInt32LE(centralSize, 12);
    end.writeUInt32LE(this.offset, 16);
    return Buffer.concat([...this.chunks, ...central, end]);
  }
}
