import { Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { HomeBanner, MediaAsset } from '../../generated/prisma/client.js';
import { MediaService } from '../media/media.service.js';
import {
  activeBannerWhere,
  BANNER_ORDER,
  bannerLinkProblem,
  HOME_BANNER_LIMIT,
  type BannerPlacement,
  type BannerTitleSide,
} from './home-banners.js';
import { eventAudienceWhere, GUEST_AUDIENCE, personAudienceOf } from '../programs/event-audience.js';

/** How many active banners are read before the running-first order and [HOME_BANNER_LIMIT] (D359). */
const BANNER_SCAN_LIMIT = 100;

/** `HomeBanner` (openapi v1.26-live draft, D124). */
export interface HomeBannerDto {
  id: string;
  imageUrl: string;
  width: number;
  height: number;
  blurhash: string | null;
  /** The overlay text in the requested language, or null (no fallback to the other language). */
  title: string | null;
  titleSide: BannerTitleSide;
  link: string;
  /**
   * v1.97-social (D303, §10.114.6): `IMAGE`, `ANIMATED` (`imageUrl` is an animated WebP) or `VIDEO` (`videoUrl`, muted,
   * looping, played only while visible). Older apps show `imageUrl` (the poster of a video) and ignore the rest.
   */
  kind: 'IMAGE' | 'ANIMATED' | 'VIDEO';
  /** The still shown before a video plays and with reduced motion (an animated picture's first frame). */
  posterUrl: string;
  videoUrl: string | null;
  /** A video's or an animation loop's length; null for a still. */
  durationMs: number | null;
  /** The event the banner opens (`link` is `/events/<id>`), else null. */
  eventId: string | null;
}

/** D124 (CONVENTIONS §10.26): the banners shown on the live hub. Read-only; the CLI writes. */
@Injectable()
export class HomeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly clock: Clock,
  ) {}

  /**
   * The active banners now, in order, at most [HOME_BANNER_LIMIT]. A row whose link no longer
   * passes the allowlist (rules tightened after it was added) is left out rather than sent.
   * v1.102-social (D334, owner: «أي فعالية يمكن أن يكون لها بانر … يظهر لجمهورها فقط»): a banner that opens an event
   * is listed only while the event is published and only to its audience — `caller` (null: a guest, EVERYONE events
   * only); a banner without an event is everyone's.
   * v1.119-social (D359, §10.154, owner: events reach the hub only through this carousel): an event banner also goes the
   * moment its event ends (`endsAt` passed — «إنهاء» included), whatever its own window says, decided at query time (no
   * sweeper); the banners of RUNNING events (started, not ended) come first, then every other banner — each group in
   * the admin's order ([BANNER_ORDER]).
   */
  async listBanners(
    language: ContentLanguage,
    placement: BannerPlacement = 'HOME',
    caller: string | null = null,
  ): Promise<HomeBannerDto[]> {
    const audience = caller === null ? GUEST_AUDIENCE : await personAudienceOf(this.prisma, caller);
    const now = this.clock.now();
    const rows = await this.prisma.homeBanner.findMany({
      where: {
        AND: [
          activeBannerWhere(now, placement),
          {
            OR: [
              { eventId: null },
              {
                event: {
                  status: 'PUBLISHED',
                  AND: [eventAudienceWhere(audience), { OR: [{ endsAt: null }, { endsAt: { gt: now } }] }],
                },
              },
            ],
          },
        ],
      },
      orderBy: BANNER_ORDER,
      // Active banners are a handful the admin made; the running-first order needs them all before the limit.
      take: BANNER_SCAN_LIMIT,
      include: { media: true, video: true, event: { select: { startsAt: true } } },
    });
    const running = (row: (typeof rows)[number]) =>
      row.event !== null && row.event.startsAt !== null && row.event.startsAt <= now;
    return [...rows.filter(running), ...rows.filter((row) => !running(row))]
      .filter((row) => bannerLinkProblem(row.link) === null)
      .slice(0, HOME_BANNER_LIMIT)
      .map((row) => ({
        id: row.id,
        imageUrl: this.media.largeUrl(row.media),
        width: row.media.width,
        height: row.media.height,
        blurhash: row.media.blurhash,
        title: (language === 'ar' ? row.titleAr : row.titleEn) ?? null,
        titleSide: row.titleSide === 'LEFT' ? 'LEFT' : 'RIGHT',
        link: row.link,
        ...this.mediaFields(row),
      }));
  }

  /** v1.97-social (D303): the kind and its media (a VIDEO whose video is gone is shown as its poster). */
  private mediaFields(row: HomeBanner & { media: MediaAsset; video: MediaAsset | null }) {
    const image = this.media.largeUrl(row.media);
    if (row.kind === 'VIDEO' && row.video) {
      return {
        kind: 'VIDEO' as const,
        posterUrl: image,
        videoUrl: this.media.largeUrl(row.video),
        durationMs: row.video.durationMs,
        eventId: row.eventId,
      };
    }
    const animated = row.kind === 'ANIMATED' && row.media.durationMs !== null;
    return {
      kind: animated ? ('ANIMATED' as const) : ('IMAGE' as const),
      posterUrl:
        animated && row.media.posterKey ? this.media.largeUrl({ largeKey: row.media.posterKey }) : image,
      videoUrl: null,
      durationMs: animated ? row.media.durationMs : null,
      eventId: row.eventId,
    };
  }
}
