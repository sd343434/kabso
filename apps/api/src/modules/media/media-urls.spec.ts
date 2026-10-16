import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { MediaUrls, publicKeys, type MediaRef } from './media-urls.js';

const OWNER = '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80';
const OTHER = '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f81';
// Generated per run: never commit a token-like literal (gitleaks).
const TOKEN = randomBytes(16).toString('base64url');
const BASE = 'https://media.example.invalid';

const ref = (over: Partial<MediaRef> = {}): MediaRef => ({
  ownerUserId: OWNER,
  purpose: 'AVATAR',
  status: 'READY',
  publicToken: TOKEN,
  moderationStatus: 'APPROVED',
  ...over,
});

describe('MediaUrls (CONVENTIONS §11.5, §11.10)', () => {
  const urls = new MediaUrls(BASE);

  it('builds URLs only from the configured base and server keys', () => {
    expect(publicKeys('AVATAR', TOKEN)).toEqual({
      main: `a/${TOKEN}/512.webp`,
      thumb: `a/${TOKEN}/128.webp`,
    });
    expect(publicKeys('ROOM_COVER', TOKEN)).toEqual({
      main: `c/${TOKEN}/960.webp`,
      thumb: `c/${TOKEN}/480.webp`,
    });
    expect(urls.urlsOf(ref())).toEqual({
      url: `${BASE}/a/${TOKEN}/512.webp`,
      thumbUrl: `${BASE}/a/${TOKEN}/128.webp`,
    });
    expect(new MediaUrls(`${BASE}/cdn`).urlsOf(ref({ purpose: 'ROOM_COVER' })).url).toBe(
      `${BASE}/cdn/c/${TOKEN}/960.webp`,
    );
  });

  it('never builds a URL from a malformed token, without a base, or for a non-READY or REJECTED image', () => {
    for (const bad of ['../../evil', 'https://evil.example/x', `${TOKEN}/../x`, '', 'short']) {
      expect(urls.urlsOf(ref({ publicToken: bad }))).toEqual({ url: null, thumbUrl: null });
    }
    expect(urls.urlsOf(ref({ publicToken: null }))).toEqual({ url: null, thumbUrl: null });
    expect(new MediaUrls(null).urlsOf(ref())).toEqual({ url: null, thumbUrl: null });
    for (const status of ['AWAITING_UPLOAD', 'FAILED', 'EXPIRED', 'DELETED']) {
      expect(urls.urlsOf(ref({ status }))).toEqual({ url: null, thumbUrl: null });
    }
    expect(urls.urlsOf(ref({ moderationStatus: 'REJECTED' }))).toEqual({ url: null, thumbUrl: null });
  });

  it('visibility: the owner sees PENDING and APPROVED; everyone else only APPROVED', () => {
    expect(urls.visibleUrls(ref({ moderationStatus: 'PENDING' }), OWNER).url).not.toBeNull();
    expect(urls.visibleUrls(ref({ moderationStatus: 'PENDING' }), OTHER)).toEqual({
      url: null,
      thumbUrl: null,
    });
    expect(urls.visibleUrls(ref({ moderationStatus: 'PENDING' }), null)).toEqual({
      url: null,
      thumbUrl: null,
    });
    expect(urls.visibleUrls(ref(), OTHER).url).not.toBeNull();
    expect(urls.visibleUrls(ref({ moderationStatus: 'REJECTED' }), OWNER)).toEqual({
      url: null,
      thumbUrl: null,
    });
    expect(urls.visibleUrls(null, OWNER)).toEqual({ url: null, thumbUrl: null });
  });
});
