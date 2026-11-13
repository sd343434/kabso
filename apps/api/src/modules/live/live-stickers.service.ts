import { randomUUID } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { liveLineSchema } from './live-program.service.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** The media data topic of sticker messages. */
export const STICKER_TOPIC = 'sticker';
/** At most this many stickers on a live at once (owner: 3). */
export const LIVE_STICKERS_MAX = 3;
/** A text sticker: 1–40 code points. */
export const LIVE_STICKER_TEXT_MAX = 40;

/** `LiveSticker` (v1.37-live, D154h, CONVENTIONS §10.38). */
export interface LiveStickerDto {
  id: string;
  artKey: string | null;
  text: string | null;
  x: number;
  y: number;
  scale: number;
  rotation: number;
}

/** `LiveStickers`: the stickers on a live now, in order (the last on top). */
export interface LiveStickersDto {
  roomId: string;
  items: LiveStickerDto[];
}

/** `LiveStickerArt`. */
export interface LiveStickerArtDto {
  key: string;
  pack: string;
}

/** The built-in pack: Kabi, the app's own art (`assets/emojis/kabi/<key>.json`). */
export const BUILT_IN_STICKERS: readonly LiveStickerArtDto[] = [
  'hi',
  'love',
  'lol',
  'wow',
  'sad',
  'angry',
  'wink',
  'live',
  'cool',
  'dizzy',
  'sleepy',
  'silly',
  'shy',
  'think',
  'party',
  'dead',
  'melt',
  'kiss',
  'gift',
  'fire',
  'crown',
  'money',
  'sing',
  'star',
].map((id) => ({ key: `kabi_${id}`, pack: 'kabi' }));

const unit = z.number().min(0).max(1);

const stickerSchema = z
  .strictObject({
    id: z.uuid().optional(),
    artKey: z.string().min(1).max(64).optional(),
    text: liveLineSchema(LIVE_STICKER_TEXT_MAX).optional(),
    x: unit,
    y: unit,
    scale: z.number().min(0.25).max(4),
    rotation: z.number().min(-Math.PI).max(Math.PI),
  })
  .refine((s) => (s.artKey === undefined) !== (s.text === undefined), {
    message: 'invalid_value',
    path: ['artKey'],
    params: { issue: 'invalid_value' },
  });

const stickersSchema = z.strictObject({
  items: z.array(stickerSchema).max(LIVE_STICKERS_MAX),
});

/**
 * Stickers on a live «ملصقات» (D154h, CONVENTIONS §10.38): the host places up to 3 — Kabi art from
 * the catalogue or a short text (masked with the host's blocked words, D99) — at positions relative
 * to the picture (0–1, so they land in the same place on every screen), with a scale and a rotation;
 * the room gets each change as `{"type":"stickers","stickers":LiveStickers}` on topic `sticker`, and
 * a late joiner reads them.
 */
@Injectable()
export class LiveStickersService {
  private readonly logger = new Logger(LiveStickersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {}

  /** `GET /live/stickers`: the art the app may place — the built-in Kabi pack, then admins' packs. */
  async catalogue(): Promise<{ items: LiveStickerArtDto[] }> {
    const rows = await this.prisma.liveStickerArt.findMany({
      where: { enabled: true },
      orderBy: [{ pack: 'asc' }, { sortOrder: 'asc' }, { key: 'asc' }],
      select: { key: true, pack: true },
    });
    const builtIn = new Set(BUILT_IN_STICKERS.map((a) => a.key));
    return { items: [...BUILT_IN_STICKERS, ...rows.filter((r) => !builtIn.has(r.key))] };
  }

  private dto(roomId: string, rows: readonly LiveStickerRow[]): LiveStickersDto {
    return {
      roomId,
      items: rows.map((r) => ({
        id: r.id,
        artKey: r.artKey,
        text: r.text,
        x: r.x,
        y: r.y,
        scale: r.scale,
        rotation: r.rotation,
      })),
    };
  }

  /** `GET /live/rooms/{roomId}/stickers`: anyone who can see the room; none once it ended. */
  async get(callerId: string | null, roomId: string): Promise<LiveStickersDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') return { roomId: row.id, items: [] };
    const rows = await this.prisma.liveSticker.findMany({
      where: { roomId: row.id },
      orderBy: { position: 'asc' },
    });
    return this.dto(row.id, rows);
  }

  /**
   * `PUT /live/rooms/{roomId}/stickers` `{items: [...]}`: replaces the stickers (empty clears them).
   * Visible room (404), the host (403 AUTH_FORBIDDEN), LIVE (409 LIVE_ROOM_ENDED), the body (400: ≤ 3;
   * exactly one of `artKey` (an enabled catalogue key, else `items.N.artKey` / `invalid_value`) and
   * `text` (1–40 code points, one line); x, y in 0–1, scale 0.25–4, rotation −π–π). A sticker keeps
   * its `id` when sent back with it.
   */
  async set(callerId: string, roomId: string, body: unknown): Promise<LiveStickersDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.host_user_id !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = stickersSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const items = parsed.data.items;
    const builtIn = new Set(BUILT_IN_STICKERS.map((a) => a.key));
    const keys = [
      ...new Set(items.flatMap((i) => (i.artKey === undefined || builtIn.has(i.artKey) ? [] : [i.artKey]))),
    ];
    if (keys.length > 0) {
      const known = new Set(
        (
          await this.prisma.liveStickerArt.findMany({
            where: { key: { in: keys }, enabled: true },
            select: { key: true },
          })
        ).map((a) => a.key),
      );
      const bad = items.findIndex(
        (i) => i.artKey !== undefined && !builtIn.has(i.artKey) && !known.has(i.artKey),
      );
      if (bad >= 0) {
        throw AppException.validation([{ field: `items.${String(bad)}.artKey`, issue: 'invalid_value' }]);
      }
    }
    const ids = items.map((i) => i.id).filter((id): id is string => id !== undefined);
    if (new Set(ids).size !== ids.length) {
      throw AppException.validation([{ field: 'items', issue: 'invalid_value' }]);
    }
    const host = await this.prisma.liveHost.findUnique({
      where: { userId: callerId },
      select: { blockedWords: true },
    });
    const words = host?.blockedWords ?? [];
    const data = items.map((i, position) => ({
      roomId: row.id,
      id: i.id ?? randomUUID(),
      position,
      artKey: i.artKey ?? null,
      text: i.text === undefined ? null : maskBlockedWords(i.text, words),
      x: i.x,
      y: i.y,
      scale: i.scale,
      rotation: i.rotation,
    }));
    const saved = await this.prisma.$transaction(async (tx) => {
      await tx.liveSticker.deleteMany({ where: { roomId: row.id } });
      if (data.length > 0) await tx.liveSticker.createMany({ data });
      return tx.liveSticker.findMany({ where: { roomId: row.id }, orderBy: { position: 'asc' } });
    });
    const stickers = this.dto(row.id, saved);
    try {
      await this.media.broadcastData(row.id, STICKER_TOPIC, JSON.stringify({ type: 'stickers', stickers }));
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send the stickers to the media room');
    }
    return stickers;
  }
}

interface LiveStickerRow {
  id: string;
  artKey: string | null;
  text: string | null;
  x: number;
  y: number;
  scale: number;
  rotation: number;
}
