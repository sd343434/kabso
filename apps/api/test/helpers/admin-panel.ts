/**
 * The admin panel helpers of d191 for one test app (moved here from d196 for D222): sign up, grant panel roles with
 * the migration role, sign in with TOTP enrolment, send with the cookie + CSRF, and a clock that steps 30 s per code.
 */
import type request from 'supertest';
import { expect, vi } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../../src/modules/admin-panel/totp.js';
import { registerVerified, withMigrationClient, type TestContext } from './test-app.js';

const COOKIE = '__Host-kabso_admin';

export interface Person {
  readonly id: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
export interface Admin extends Person {
  secret: string;
  cookie: string;
  csrf: string;
}

/** The panel helpers of d191, for one app. */
export function panel(getCtx: () => TestContext) {
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const signup = async (): Promise<Person> => {
    const { res, payload } = await registerVerified(getCtx());
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      email: payload.email,
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const ctx = getCtx();
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const send = (a: Admin, method: 'get' | 'post' | 'patch' | 'put', path: string, body?: object) => {
    const r = getCtx().http[method](`/api/v1${path}`).set('Cookie', a.cookie);
    return method === 'get' ? r : r.set('X-CSRF-Token', a.csrf).send(body ?? {});
  };
  return { advance, nextCode, signup, makeAdmin, send, now: () => clock, start: () => clock };
}
