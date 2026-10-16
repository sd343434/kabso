import { Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { PrismaService } from '../../prisma/prisma.service.js';

/** `LiveCategory` (openapi): the slug and the name in the resolved language (§10.1). */
export interface LiveCategoryDto {
  slug: string;
  name: string;
}

/** Hard cap on active categories (CONVENTIONS §10.1); the list is returned unpaginated. */
export const MAX_ACTIVE_CATEGORIES = 100;

export function localizedCategory(
  row: { slug: string; nameAr: string; nameEn: string },
  lang: ContentLanguage,
): LiveCategoryDto {
  return { slug: row.slug, name: lang === 'en' ? row.nameEn : row.nameAr };
}

/**
 * Server-curated live categories (`live_categories`, owned by the live module). Read-only in
 * v1.3: none are seeded (D37) and admin management is a later contract version.
 */
@Injectable()
export class LiveCategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Active categories by `sortOrder`, then `slug` (bounded by the 100-row cap). */
  async listActive(lang: ContentLanguage): Promise<LiveCategoryDto[]> {
    const rows = await this.prisma.liveCategory.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
      take: MAX_ACTIVE_CATEGORIES,
      select: { slug: true, nameAr: true, nameEn: true },
    });
    return rows.map((row) => localizedCategory(row, lang));
  }

  /** Id of an ACTIVE category, else null (unknown and inactive are treated alike). */
  async findActiveId(slug: string): Promise<string | null> {
    const row = await this.prisma.liveCategory.findFirst({
      where: { slug, isActive: true },
      select: { id: true },
    });
    return row?.id ?? null;
  }
}
