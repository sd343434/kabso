/**
 * Value-based redaction for free text that may end up in logs (error messages, stacks). pino's
 * `redact` only matches keys; Prisma and driver errors embed argument values in their message
 * (SEC-017), so known secret shapes are masked here.
 */
const CENSOR = '[REDACTED]';

const PATTERNS: readonly RegExp[] = [
  // `password: "…"`, `"refreshTokenHash": '…'`, `token=…` (Prisma invocation dumps, query strings)
  /((?:password|passwordhash|newpassword|token|tokenhash|refreshtoken|refreshtokenhash|accesstoken|secret|authorization)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,})\]]+)/gi,
  // v1.4: presigned storage URLs are bearer credentials for one object (CONVENTIONS §11.3,
  // §11.11): mask the signature and credential query parameters wherever they appear.
  /((?:X-Amz-Signature|X-Amz-Credential|X-Amz-Security-Token)=)[^&\s"']+/gi,
  // Bearer credentials
  /(bearer\s+)[A-Za-z0-9._~+/-]+=*/gi,
  // JWTs
  /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/g,
  // Argon2 PHC strings
  /\$argon2(?:id|i|d)\$[^\s"',]+/g,
  // Refresh tokens <uuid>.<secret> and bare 43-char base64url secrets
  /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.[A-Za-z0-9_-]{43}/gi,
  /(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{43}(?![A-Za-z0-9_-])/g,
  // SHA-256 hex digests (stored token hashes)
  /(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])/gi,
  // Email addresses
  /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g,
];

export function redactText(text: string): string {
  let out = text;
  for (const pattern of PATTERNS) {
    out = out.replace(pattern, (match: string, prefix?: unknown) =>
      typeof prefix === 'string' && match.startsWith(prefix) ? `${prefix}${CENSOR}` : CENSOR,
    );
  }
  return out;
}

export interface SafeErrorLog {
  name: string;
  message: string;
  stack?: string;
}

/** Only name, message and stack of an error — each value-redacted and bounded. */
export function safeErrorLog(error: unknown): SafeErrorLog {
  if (error instanceof Error) {
    return {
      name: error.name.slice(0, 100),
      message: redactText(error.message).slice(0, 2000),
      ...(error.stack ? { stack: redactText(error.stack).slice(0, 8000) } : {}),
    };
  }
  return { name: typeof error, message: redactText(String(error)).slice(0, 2000) };
}
