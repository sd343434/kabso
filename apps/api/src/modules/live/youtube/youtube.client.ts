import { Inject, Injectable, Logger } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../../config/app-config.js';
import { safeErrorLog } from '../../../logging/redact-text.js';

/** A YouTube video as watch-together shows it (`LiveWatchVideo`). */
export interface YoutubeVideo {
  videoId: string;
  title: string;
  channel: string | null;
  thumbnailUrl: string;
}

/** Reads YouTube for watch-together (D154i). Never throws for a missing video: null. */
export interface YoutubeClient {
  /** Whether search is set up (a Data API key). */
  readonly searchEnabled: boolean;
  /** The video, or null when it does not exist or may not be embedded. Throws when YouTube is unreachable. */
  video(videoId: string): Promise<YoutubeVideo | null>;
  /** Embeddable videos for [query]; throws when search is off or YouTube is unreachable. */
  search(query: string, language: string): Promise<YoutubeVideo[]>;
}

export const YOUTUBE_CLIENT = Symbol('YOUTUBE_CLIENT');

const ID = /^[A-Za-z0-9_-]{11}$/;

/**
 * The 11-character video id of [input]: an id, or a youtube.com / youtu.be link (watch, shorts,
 * embed, live, music, mobile); null otherwise.
 */
export function youtubeVideoId(input: string): string | null {
  const text = input.trim();
  if (ID.test(text)) return text;
  let url: URL;
  try {
    url = new URL(/^https?:\/\//i.test(text) ? text : `https://${text}`);
  } catch {
    return null;
  }
  const host = url.hostname.toLowerCase().replace(/^(www|m|music)\./, '');
  let id: string | null = null;
  if (host === 'youtu.be') {
    id = url.pathname.split('/')[1] ?? null;
  } else if (host === 'youtube.com' || host === 'youtube-nocookie.com') {
    const parts = url.pathname.split('/').filter((p) => p.length > 0);
    if (parts[0] === 'watch') id = url.searchParams.get('v');
    else if (['shorts', 'embed', 'live', 'v'].includes(parts[0] ?? '')) id = parts[1] ?? null;
  }
  return id !== null && ID.test(id) ? id : null;
}

export function thumbnailOf(videoId: string): string {
  return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
}

const TIMEOUT_MS = 5_000;
const CACHE_MS = 10 * 60_000;
const CACHE_MAX = 300;

/**
 * [YoutubeClient] over HTTPS: a video through YouTube's oEmbed (no key; 401/403/404 mean not
 * embeddable or missing), search through the Data API v3 (`search.list`, embeddable videos only, safe
 * search moderate) with the server's YOUTUBE_API_KEY. Search answers are kept 10 min per query (the
 * free quota is about 100 searches a day).
 */
@Injectable()
export class HttpYoutubeClient implements YoutubeClient {
  private readonly logger = new Logger(HttpYoutubeClient.name);
  private readonly cache = new Map<string, { at: number; items: YoutubeVideo[] }>();

  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  get searchEnabled(): boolean {
    return this.config.youtubeApiKey !== null;
  }

  async video(videoId: string): Promise<YoutubeVideo | null> {
    const watch = `https://www.youtube.com/watch?v=${videoId}`;
    const res = await fetch(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent(watch)}`, {
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if ([400, 401, 403, 404].includes(res.status)) return null;
    if (!res.ok) throw new Error(`YouTube oEmbed answered ${String(res.status)}`);
    const body = (await res.json()) as { title?: unknown; author_name?: unknown };
    return {
      videoId,
      title: typeof body.title === 'string' ? body.title : videoId,
      channel: typeof body.author_name === 'string' ? body.author_name : null,
      thumbnailUrl: thumbnailOf(videoId),
    };
  }

  async search(query: string, language: string): Promise<YoutubeVideo[]> {
    const key = this.config.youtubeApiKey;
    if (key === null) throw new Error('YouTube search is off');
    const cacheKey = `${language}:${query.toLowerCase()}`;
    const now = Date.now();
    const hit = this.cache.get(cacheKey);
    if (hit && now - hit.at < CACHE_MS) return hit.items;
    const params = new URLSearchParams({
      part: 'snippet',
      type: 'video',
      videoEmbeddable: 'true',
      safeSearch: 'moderate',
      maxResults: '10',
      relevanceLanguage: language,
      q: query,
      key,
    });
    let res: Response;
    try {
      res = await fetch(`https://www.googleapis.com/youtube/v3/search?${params.toString()}`, {
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'YouTube search failed');
      throw err;
    }
    if (!res.ok) throw new Error(`YouTube search answered ${String(res.status)}`);
    const body = (await res.json()) as {
      items?: { id?: { videoId?: unknown }; snippet?: { title?: unknown; channelTitle?: unknown } }[];
    };
    const items: YoutubeVideo[] = [];
    for (const item of body.items ?? []) {
      const id = item.id?.videoId;
      if (typeof id !== 'string' || !ID.test(id)) continue;
      items.push({
        videoId: id,
        title: typeof item.snippet?.title === 'string' ? decodeEntities(item.snippet.title) : id,
        channel: typeof item.snippet?.channelTitle === 'string' ? item.snippet.channelTitle : null,
        thumbnailUrl: thumbnailOf(id),
      });
    }
    if (this.cache.size >= CACHE_MAX) this.cache.delete(this.cache.keys().next().value!);
    this.cache.set(cacheKey, { at: now, items });
    return items;
  }
}

/** The Data API returns HTML-escaped titles. */
function decodeEntities(text: string): string {
  return text
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}
