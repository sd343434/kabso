import type { TestContext } from './test-app.js';

/** A MULTI seat count of the days before D369 (host tile included). */
export type LegacyMultiSeatCount = 4 | 6 | 9 | 12;

/**
 * v1.116-live (D369, CONVENTIONS §10.162): MULTI is retired — `startLiveRoom` refuses it (400 `mode` /
 * `invalid_value`) — but a MULTI room started before the deploy runs on until it ends. Suites that cover such a
 * room build one the only way left: the host starts a SOLO live through the API and the room is then set to MULTI
 * (with its seat count) in the database, as a room of an older app would be. Every other field of `body` (title,
 * theme, category, …) goes to the start request. Returns the room id.
 */
export async function startLegacyMulti(
  ctx: Pick<TestContext, 'http' | 'prisma'>,
  token: string,
  body: { readonly seatCount?: LegacyMultiSeatCount; readonly [key: string]: unknown } = {},
): Promise<string> {
  const { seatCount = 4, mode: _mode, ...rest } = body;
  const res = await ctx.http
    .post('/api/v1/live/rooms')
    .set('Authorization', `Bearer ${token}`)
    .send({ title: 'Multi', ...rest });
  if (res.status !== 201) {
    throw new Error(`startLegacyMulti: go-live answered ${String(res.status)} ${JSON.stringify(res.body)}`);
  }
  const id = res.body.id as string;
  await ctx.prisma.liveRoom.update({ where: { id }, data: { mode: 'MULTI', seatCount } });
  return id;
}
