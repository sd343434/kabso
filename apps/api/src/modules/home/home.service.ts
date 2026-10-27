import { Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MediaService } from '../media/media.service.js';
import {
  activeBannerWhere,
  BANNER_ORDER,
  bannerLinkProblem,
  HOME_BANNER_LIMIT,
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
  async listBanners(language: ContentLanguage): Promise<HomeBannerDto[]> {
    const rows = await this.prisma.homeBanner.findMany({
      where: activeBannerWhere(this.clock.now()),
      orderBy: BANNER_ORDER,
      take: HOME_BANNER_LIMIT,
      include: { media: true },
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
      }));
  }
}
