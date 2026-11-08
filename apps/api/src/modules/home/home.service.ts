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
   */
  async listBanners(
    language: ContentLanguage,
    placement: BannerPlacement = 'HOME',
  ): Promise<HomeBannerDto[]> {
    const rows = await this.prisma.homeBanner.findMany({
      where: activeBannerWhere(this.clock.now(), placement),
      orderBy: BANNER_ORDER,
      take: HOME_BANNER_LIMIT,
      include: { media: true, video: true },
    });
    return rows
      .filter((row) => bannerLinkProblem(row.link) === null)
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
