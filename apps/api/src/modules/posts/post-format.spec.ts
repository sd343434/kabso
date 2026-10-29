import { describe, expect, it } from 'vitest';
import { mediaShapeAllowed } from './posts.service.js';

describe('post media shapes (v1.41-social, D162, CONVENTIONS §11.14)', () => {
  it('a reel is exactly one REEL_VIDEO', () => {
    expect(mediaShapeAllowed('REEL', ['REEL_VIDEO'])).toBe(true);
    expect(mediaShapeAllowed('REEL', [])).toBe(false);
    expect(mediaShapeAllowed('REEL', ['REEL_VIDEO', 'REEL_VIDEO'])).toBe(false);
    expect(mediaShapeAllowed('REEL', ['POST_VIDEO'])).toBe(false);
    expect(mediaShapeAllowed('REEL', ['POST_IMAGE'])).toBe(false);
  });

  it('a post is photos only, or exactly one POST_VIDEO', () => {
    expect(mediaShapeAllowed('POST', [])).toBe(true);
    expect(mediaShapeAllowed('POST', ['POST_IMAGE', 'POST_IMAGE'])).toBe(true);
    expect(mediaShapeAllowed('POST', ['POST_VIDEO'])).toBe(true);
    expect(mediaShapeAllowed('POST', ['POST_VIDEO', 'POST_IMAGE'])).toBe(false);
    expect(mediaShapeAllowed('POST', ['POST_VIDEO', 'POST_VIDEO'])).toBe(false);
    expect(mediaShapeAllowed('POST', ['REEL_VIDEO'])).toBe(false);
  });
});
