import { describe, expect, it } from 'vitest';
import { Clock } from '../../common/time/clock.js';
import type { AppConfig } from '../../config/app-config.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import { LIVE_CHAT_BADGES_TTL_MS, LiveChatBadgesService, NO_BADGES } from './live-chat-badges.service.js';

class FakeClock extends Clock {
  ms = Date.parse('2026-10-26T12:00:00.000Z');
  now(): Date {
    return new Date(this.ms);
  }
}

const A = '0192f1d0-0000-7000-8000-00000000000a';
const B = '0192f1d0-0000-7000-8000-00000000000b';
const config = { newcomerDays: 30 } as AppConfig;

/** A Prisma stand-in whose `$queryRaw` answers rows for the ids it is asked about. */
function fakePrisma(
  rows: Record<string, { charm: number | null; family: string | null; newcomer?: boolean }>,
) {
  const asked: string[][] = [];
  const prisma = {
    $queryRaw: (_strings: TemplateStringsArray, ...values: unknown[]) => {
      const ids = values.find((v): v is string[] => Array.isArray(v)) ?? [];
      asked.push([...ids]);
      return Promise.resolve(
        ids
          .filter((id) => id in rows)
          .map((id) => ({
            user_id: id,
            charm_level: rows[id]!.charm,
            support_level: null,
            family_name: rows[id]!.family,
            family_level: rows[id]!.family === null ? null : 2,
            newcomer: rows[id]!.newcomer ?? false,
          })),
      );
    },
  };
  return { prisma: prisma as unknown as PrismaService, asked };
}

describe('D119 live chat author badges', () => {
  it('maps a row; a missing row (or family) is no badges', async () => {
    const { prisma } = fakePrisma({ [A]: { charm: 7, family: 'Stars', newcomer: true } });
    const service = new LiveChatBadgesService(prisma, new FakeClock(), config);
    const badges = await service.of([A, B]);
    expect(badges.get(A)).toEqual({
      charmLevel: 7,
      supportLevel: null,
      family: { name: 'Stars', level: 2 },
      newcomer: true,
    });
    expect(badges.get(B)).toEqual(NO_BADGES);
  });

  it('reads each author once per page and caches them for 30 s', async () => {
    const clock = new FakeClock();
    const { prisma, asked } = fakePrisma({
      [A]: { charm: 1, family: null },
      [B]: { charm: 2, family: null },
    });
    const service = new LiveChatBadgesService(prisma, clock, config);
    await service.of([A, A, B]);
    expect(asked).toEqual([[A, B]]);
    await service.one(A);
    clock.ms += LIVE_CHAT_BADGES_TTL_MS - 1;
    await service.of([A, B]);
    expect(asked).toHaveLength(1);
    clock.ms += 1;
    await service.one(B);
    expect(asked).toEqual([[A, B], [B]]);
  });

  it('a clock that went backwards reads again', async () => {
    const clock = new FakeClock();
    const { prisma, asked } = fakePrisma({ [A]: { charm: 1, family: null } });
    const service = new LiveChatBadgesService(prisma, clock, config);
    await service.one(A);
    clock.ms -= 1000;
    await service.one(A);
    expect(asked).toHaveLength(2);
  });
});
