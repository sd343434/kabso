import { describe, expect, it } from 'vitest';
import { youtubeVideoId } from './youtube.client.js';

describe('youtubeVideoId (D154i)', () => {
  it('reads ids and the usual links', () => {
    const id = 'dQw4w9WgXcQ';
    for (const ref of [
      id,
      ` ${id} `,
      `https://www.youtube.com/watch?v=${id}&t=42s`,
      `youtube.com/watch?v=${id}`,
      `https://m.youtube.com/watch?v=${id}`,
      `https://music.youtube.com/watch?v=${id}`,
      `https://youtu.be/${id}?si=abc`,
      `https://www.youtube.com/shorts/${id}`,
      `https://www.youtube.com/embed/${id}`,
      `https://www.youtube.com/live/${id}`,
      `https://www.youtube-nocookie.com/embed/${id}`,
    ]) {
      expect(youtubeVideoId(ref), ref).toBe(id);
    }
  });

  it('refuses anything else', () => {
    for (const ref of [
      '',
      'short',
      'https://vimeo.com/123456789',
      'https://evil.example/watch?v=dQw4w9WgXcQ',
      'https://www.youtube.com/watch?v=tooShort',
      'https://www.youtube.com/channel/UC123',
      'javascript:alert(1)',
    ]) {
      expect(youtubeVideoId(ref), ref).toBeNull();
    }
  });
});
