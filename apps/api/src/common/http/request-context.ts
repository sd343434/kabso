import { isIPv4, isIPv6 } from 'node:net';
import type { Request } from 'express';

/** Identity attached to the request by the access-token guard. */
export interface AuthContext {
  readonly userId: string;
  readonly sessionId: string;
}

export type AppRequest = Request & { auth?: AuthContext };

/** Client IP as resolved by Express (honours the configured `trust proxy`). */
export function clientIp(req: Request): string {
  return req.ip ?? req.socket.remoteAddress ?? 'unknown';
}

/** Expands an IPv6 address (no zone id) to 8 hextets, or null when it is not one. */
export function ipv6Hextets(address: string): number[] | null {
  if (!isIPv6(address)) return null;
  let text = address;
  // Rewrite an embedded IPv4 tail (e.g. ::ffff:192.0.2.1) as two hextets.
  const v4 = /(\d{1,3}(?:\.\d{1,3}){3})$/.exec(text);
  if (v4?.[1]) {
    const [a = 0, b = 0, c = 0, d = 0] = v4[1].split('.').map(Number);
    text = `${text.slice(0, -v4[1].length)}${((a << 8) | b).toString(16)}:${((c << 8) | d).toString(16)}`;
  }
  const parse = (part: string) => (part === '' ? [] : part.split(':').map((h) => parseInt(h, 16)));
  const [head = '', rest] = text.split('::');
  const left = parse(head);
  const right = rest === undefined ? [] : parse(rest);
  const groups =
    rest === undefined ? left : [...left, ...Array<number>(8 - left.length - right.length).fill(0), ...right];
  return groups.length === 8 && groups.every((g) => Number.isInteger(g) && g >= 0 && g <= 0xffff)
    ? groups
    : null;
}

/**
 * Subject used for IP-based rate-limit buckets (CONVENTIONS §7): IPv4 addresses as-is
 * (IPv4-mapped IPv6 is unwrapped), IPv6 grouped by its /64 prefix, since one subscriber
 * typically controls a whole /64.
 */
export function rateLimitIpSubject(ip: string): string {
  const bare = ip.split('%')[0] ?? ip;
  if (isIPv4(bare)) return bare;
  const groups = ipv6Hextets(bare);
  if (!groups) return bare;
  if (groups.slice(0, 5).every((g) => g === 0) && groups[5] === 0xffff) {
    const [hi = 0, lo = 0] = groups.slice(6);
    return `${hi >> 8}.${hi & 0xff}.${lo >> 8}.${lo & 0xff}`;
  }
  return `${groups
    .slice(0, 4)
    .map((g) => g.toString(16))
    .join(':')}::/64`;
}

/** The client IP as a rate-limit subject (IPv6 → /64). */
export function clientIpBucket(req: Request): string {
  return rateLimitIpSubject(clientIp(req));
}

export function userAgent(req: Request): string | null {
  const ua = req.headers['user-agent'];
  return typeof ua === 'string' && ua.length > 0 ? ua.slice(0, 512) : null;
}
