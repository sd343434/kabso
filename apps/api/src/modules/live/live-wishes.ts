/**
 * v1.27.3-live (D136, owner 2026-10-27; CONVENTIONS §10.29): the host's wish list — up to 4 gifts
 * from the catalogue shown in the room, each with how many of it the host received in this live.
 */
import type { ContentLanguage } from '../../common/http/content-language.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { giftArtDto, giftName } from '../gifts/gifts.service.js';

/** `LiveWishGift`. */
export interface LiveWishGiftDto {
  giftCode: string;
  name: string;
  priceCoins: number;
  assetKey: string;
  imageUrl: string | null;
  /** How many of this gift the host received in this live (every send that named the host). */
  received: number;
}

type Db = Pick<Prisma.TransactionClient, 'gift' | '$queryRaw'>;

/**
 * The codes of [codes] that can be wished now: an enabled gift, and a `LUCKY` one only while
 * lucky gifts are on (the panel lists nothing else, §10.27).
 */
export async function availableWishCodes(
  db: Db,
  codes: readonly string[],
  luckyEnabled: boolean,
): Promise<Set<string>> {
  if (codes.length === 0) return new Set();
  const gifts = await db.gift.findMany({
    where: { code: { in: [...codes] }, enabled: true },
    select: { code: true, category: true },
  });
  return new Set(gifts.filter((g) => g.category !== 'LUCKY' || luckyEnabled).map((g) => g.code));
}

/**
 * The wish list of a room as shown: the available gifts of [codes] in their order, names by
 * [lang], with the host's received count in this live. A gift that became unavailable is left out.
 */
export async function wishGiftsOf(
  db: Db,
  input: {
    roomId: string;
    hostId: string;
    codes: readonly string[];
    lang: ContentLanguage;
    publicBaseUrl: string | undefined;
    luckyEnabled: boolean;
  },
): Promise<LiveWishGiftDto[]> {
  const { codes } = input;
  if (codes.length === 0) return [];
  const gifts = await db.gift.findMany({ where: { code: { in: [...codes] }, enabled: true } });
  const byCode = new Map(
    gifts.filter((g) => g.category !== 'LUCKY' || input.luckyEnabled).map((g) => [g.code, g]),
  );
  if (byCode.size === 0) return [];
  const counts = await db.$queryRaw<{ gift_code: string; received: bigint }[]>`
    SELECT g.gift_code, SUM(g.quantity)::bigint AS received
      FROM live_gifts g
      JOIN live_gift_recipients r ON r.gift_id = g.id AND r.user_id = ${input.hostId}::uuid
     WHERE g.room_id = ${input.roomId}::uuid AND g.gift_code = ANY(${[...byCode.keys()]}::varchar[])
     GROUP BY g.gift_code`;
  const received = new Map(counts.map((c) => [c.gift_code, Number(c.received)]));
  return codes.flatMap((code) => {
    const gift = byCode.get(code);
    if (!gift) return [];
    return [
      {
        giftCode: gift.code,
        name: giftName(gift, input.lang),
        priceCoins: gift.priceCoins,
        assetKey: gift.assetKey,
        imageUrl: giftArtDto(gift, input.publicBaseUrl).imageUrl,
        received: received.get(code) ?? 0,
      },
    ];
  });
}
