// v1.84-live (D302, CONVENTIONS §10.96.12; owner: «المشرفين يدخلون من خلال وضع الايدي المميز والباسورد»): the app sign-in
// takes a staff ID as the identifier — its CURRENT holder only; a retired / suspended number reads like any unknown name.
import { describe, expect, it, vi } from 'vitest';
import { AuditAction } from '../../common/audit/audit.service.js';
import { type AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { AuthService } from './auth.service.js';

const META = { ip: '203.0.113.9', ipBucket: '203.0.113.0', userAgent: 'ua', requestId: 'req-1' };
const STAFF = { id: 'u-staff', passwordHash: 'h', status: 'ACTIVE', passwordChangeRequiredAt: null };

function service(opts: { holder: string | null }) {
  const prisma = { $queryRaw: vi.fn().mockResolvedValue(opts.holder ? [{ id: opts.holder }] : []) };
  const users = {
    findLoginCandidate: vi.fn(async (where: Record<string, string>) =>
      where.id === STAFF.id ? STAFF : null,
    ),
  };
  const passwords = {
    verify: vi.fn().mockResolvedValue(false),
    verifyAgainstDummy: vi.fn().mockResolvedValue(false),
  };
  const audit = { record: vi.fn().mockResolvedValue(undefined) };
  const rateLimits = {
    consume: vi.fn().mockResolvedValue(undefined),
    hasFlag: vi.fn().mockResolvedValue(false),
    refund: vi.fn().mockResolvedValue(undefined),
  };
  const none = {} as never;
  const auth = new AuthService(
    prisma as never,
    users as never,
    none,
    none,
    passwords as never,
    none,
    audit as never,
    rateLimits as never,
    none,
    none,
    { rateLimits: { loginIpAccount: {}, loginAccount: {} } } as never,
  );
  return { auth, prisma, users, passwords, audit, rateLimits };
}

async function errorOf(p: Promise<unknown>): Promise<AppException> {
  try {
    await p;
  } catch (err) {
    return err as AppException;
  }
  throw new Error('no error');
}

describe('AuthService.login with a staff ID (D302)', () => {
  it.each(['Kabso01', 'kabso1', '@KABSO01', ' kabso001 '])(
    '%s → the current holder is the candidate (one account bucket with its username / email)',
    async (identifier) => {
      const { auth, prisma, users, passwords, audit, rateLimits } = service({ holder: STAFF.id });
      const err = await errorOf(auth.login({ identifier, password: 'wrong' }, META));
      expect(err.code).toBe(ErrorCode.AUTH_INVALID_CREDENTIALS);
      expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
      expect(prisma.$queryRaw.mock.calls[0]!.slice(1)).toContain(1);
      expect(users.findLoginCandidate).toHaveBeenCalledWith({ id: STAFF.id });
      expect(passwords.verify).toHaveBeenCalledWith('h', 'wrong');
      expect(rateLimits.consume).toHaveBeenCalledWith('login:account', `user:${STAFF.id}`, {});
      expect(audit.record).toHaveBeenCalledWith(
        expect.objectContaining({
          action: AuditAction.LOGIN_FAILURE,
          actorUserId: STAFF.id,
          metadata: { identifierType: 'staff_id', reason: 'bad_password' },
        }),
      );
    },
  );

  it('«Kabso» is number 0 (the primary OWNER)', async () => {
    const { auth, prisma } = service({ holder: STAFF.id });
    await errorOf(auth.login({ identifier: 'Kabso', password: 'x' }, META));
    expect(prisma.$queryRaw.mock.calls[0]!.slice(1)).toContain(0);
  });

  it('a retired / suspended number (no holder) reads as before: the same error as an unknown username', async () => {
    const retired = service({ holder: null });
    const e1 = await errorOf(retired.auth.login({ identifier: 'Kabso05', password: 'x' }, META));
    expect(retired.users.findLoginCandidate).toHaveBeenCalledWith({ username: 'kabso05' });
    expect(retired.passwords.verifyAgainstDummy).toHaveBeenCalledWith('x');
    expect(retired.audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ metadata: { identifierType: 'username', reason: 'unknown_identifier' } }),
    );
    const unknown = service({ holder: null });
    const e2 = await errorOf(unknown.auth.login({ identifier: 'nobody', password: 'x' }, META));
    expect(unknown.prisma.$queryRaw).not.toHaveBeenCalled();
    expect({ code: e1.code, status: e1.status, message: e1.message, details: e1.details }).toEqual({
      code: e2.code,
      status: e2.status,
      message: e2.message,
      details: e2.details,
    });
    // «@kabso05» without a holder is read as before (an email that no account has).
    const at = service({ holder: null });
    await errorOf(at.auth.login({ identifier: '@kabso05', password: 'x' }, META));
    expect(at.users.findLoginCandidate).toHaveBeenCalledWith({ email: '@kabso05' });
  });

  it('look-alikes and emails never look up a staff ID', async () => {
    for (const identifier of ['kabs01', 'kabso01x', 'k4bso01', 'Kabso00', 'kabso@example.com']) {
      const s = service({ holder: STAFF.id });
      await errorOf(s.auth.login({ identifier, password: 'x' }, META));
      expect(s.prisma.$queryRaw, identifier).not.toHaveBeenCalled();
      expect(s.users.findLoginCandidate, identifier).not.toHaveBeenCalledWith({ id: STAFF.id });
    }
  });
});
