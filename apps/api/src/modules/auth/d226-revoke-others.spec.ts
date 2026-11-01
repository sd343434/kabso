// v1.79-social (D226, CONVENTIONS §10.76): «تسجيل الخروج من كل الأجهزة الأخرى».
import { describe, expect, it, vi } from 'vitest';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { revokeOtherSessionsSchema } from './auth.schemas.js';
import { AuthService } from './auth.service.js';
import { RevokedReason, SessionsService } from './sessions.service.js';

const META = { ip: '203.0.113.9', ipBucket: '203.0.113.0', userAgent: 'ua', requestId: 'req-1' };

function service(opts: { passwordOk: boolean; revoked?: number; user?: boolean }) {
  const prisma = {
    user: {
      findUnique: vi.fn().mockResolvedValue(opts.user === false ? null : { passwordHash: 'hash' }),
    },
  };
  const sessions = { revokeOthers: vi.fn().mockResolvedValue(opts.revoked ?? 0) };
  const passwords = { verify: vi.fn().mockResolvedValue(opts.passwordOk) };
  const audit = { record: vi.fn().mockResolvedValue(undefined) };
  const none = {} as never;
  const auth = new AuthService(
    prisma as never,
    none,
    sessions as never,
    none,
    passwords as never,
    none,
    audit as never,
    none,
    none,
    none,
    none,
  );
  return { auth, prisma, sessions, passwords, audit };
}

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (err) {
    return (err as AppException).code;
  }
  return undefined;
}

describe('AuthService.revokeOtherSessions', () => {
  it('right password: ends the other sessions, keeps this one, audits the count', async () => {
    const { auth, sessions, passwords, audit } = service({ passwordOk: true, revoked: 3 });
    await expect(auth.revokeOtherSessions('u1', 's-current', 'secret', META)).resolves.toEqual({
      revoked: 3,
    });
    expect(passwords.verify).toHaveBeenCalledWith('hash', 'secret');
    expect(sessions.revokeOthers).toHaveBeenCalledWith('u1', 's-current', RevokedReason.USER_REVOKED);
    expect(audit.record).toHaveBeenCalledWith({
      action: AuditAction.SESSIONS_REVOKED_OTHERS,
      actorUserId: 'u1',
      targetType: 'session',
      targetId: 's-current',
      metadata: { count: 3 },
      ip: META.ip,
      requestId: META.requestId,
    });
  });

  it('no other session: 0, still audited', async () => {
    const { auth, audit } = service({ passwordOk: true, revoked: 0 });
    await expect(auth.revokeOtherSessions('u1', 's1', 'secret', META)).resolves.toEqual({ revoked: 0 });
    expect(audit.record).toHaveBeenCalledWith(expect.objectContaining({ metadata: { count: 0 } }));
  });

  it('wrong password: 403 REAUTH_FAILED, audited, nothing revoked', async () => {
    const { auth, sessions, audit } = service({ passwordOk: false });
    expect(await codeOf(auth.revokeOtherSessions('u1', 's1', 'nope', META))).toBe(ErrorCode.REAUTH_FAILED);
    expect(sessions.revokeOthers).not.toHaveBeenCalled();
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: AuditAction.SESSIONS_REVOKE_OTHERS_REAUTH_FAILED,
        actorUserId: 'u1',
        targetId: 'u1',
      }),
    );
  });

  it('a user that no longer exists: 401', async () => {
    const { auth, sessions } = service({ passwordOk: true, user: false });
    expect(await codeOf(auth.revokeOtherSessions('u1', 's1', 'x', META))).toBe(
      ErrorCode.AUTH_UNAUTHENTICATED,
    );
    expect(sessions.revokeOthers).not.toHaveBeenCalled();
  });
});

describe('SessionsService.revokeOthers', () => {
  it('revokes every live session but the current one and drops their push tokens, in one transaction', async () => {
    const tx = {
      session: { updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
      deviceToken: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
    };
    const prisma = { $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)) };
    const sessions = new SessionsService(prisma as never, {} as never);
    const now = new Date('2026-11-01T12:00:00Z');
    await expect(sessions.revokeOthers('u1', 's-current', RevokedReason.USER_REVOKED, now)).resolves.toBe(2);
    expect(prisma.$transaction).toHaveBeenCalledOnce();
    expect(tx.session.updateMany).toHaveBeenCalledWith({
      where: { userId: 'u1', revokedAt: null, id: { not: 's-current' } },
      data: { revokedAt: now, revokedReason: RevokedReason.USER_REVOKED },
    });
    expect(tx.deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'u1', sessionId: { not: 's-current' } },
    });
  });
});

describe('RevokeOtherSessionsRequest', () => {
  const pipe = new ZodValidationPipe(revokeOtherSessionsSchema);
  it('takes the password (NFC) and nothing else', () => {
    expect(pipe.transform({ password: 'cafe\u0301' })).toEqual({ password: 'café' });
    expect(() => pipe.transform({})).toThrow(AppException);
    expect(() => pipe.transform({ password: '' })).toThrow(AppException);
    expect(() => pipe.transform({ password: 'x'.repeat(129) })).toThrow(AppException);
    expect(() => pipe.transform({ password: 'ok', extra: 1 })).toThrow(AppException);
  });
});
