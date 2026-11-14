import { describe, expect, it } from 'vitest';
import { capabilitiesOf, capabilityNote, detectPlatform, displayMediaOptions } from '../src/capabilities';
import { QUALITIES } from '../src/devices';

const UA = {
  winChrome: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  winEdge: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
  macChrome: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  macSafari: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15',
  linuxFirefox: 'Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0',
  linuxChrome: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  chromeOs: 'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
  android: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36',
  iphone: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',
};

const capsOf = (ua: string, displayMedia = true) => capabilitiesOf(detectPlatform(ua), displayMedia);

describe('OS / browser capability notes', () => {
  it('reads the OS and the browser', () => {
    expect(detectPlatform(UA.winChrome)).toEqual({ os: 'windows', browser: 'chrome' });
    expect(detectPlatform(UA.winEdge)).toEqual({ os: 'windows', browser: 'edge' });
    expect(detectPlatform(UA.macChrome)).toEqual({ os: 'mac', browser: 'chrome' });
    expect(detectPlatform(UA.macSafari)).toEqual({ os: 'mac', browser: 'safari' });
    expect(detectPlatform(UA.linuxFirefox)).toEqual({ os: 'linux', browser: 'firefox' });
    expect(detectPlatform(UA.chromeOs)).toEqual({ os: 'chromeos', browser: 'chrome' });
    expect(detectPlatform(UA.android)).toEqual({ os: 'android', browser: 'chrome' });
    expect(detectPlatform(UA.iphone)).toEqual({ os: 'ios', browser: 'safari' });
    // Client hints win over a frozen user agent.
    expect(detectPlatform('Mozilla/5.0 (X11) Chrome/141', 'Windows').os).toBe('windows');
  });

  it('Windows Chrome / Edge: system sound with the screen, tab sound with a tab', () => {
    for (const ua of [UA.winChrome, UA.winEdge, UA.chromeOs]) {
      const c = capsOf(ua);
      expect(c.audio).toBe('system-and-tab');
      expect(capabilityNote(c)).toBe('capSystemAudio');
    }
  });

  it('Mac and Linux Chromium: tab sound only; Firefox and Safari: no sound', () => {
    expect(capabilityNote(capsOf(UA.macChrome))).toBe('capMacTabAudio');
    expect(capsOf(UA.macChrome).audio).toBe('tab-only');
    expect(capabilityNote(capsOf(UA.linuxChrome))).toBe('capLinuxTabAudio');
    expect(capabilityNote(capsOf(UA.linuxFirefox))).toBe('capNoAudioFirefox');
    expect(capabilityNote(capsOf(UA.macSafari))).toBe('capNoAudioSafari');
    expect(capsOf(UA.macSafari).audio).toBe('none');
  });

  it('phones cannot share a screen from a browser; a browser without getDisplayMedia neither', () => {
    expect(capsOf(UA.android).screen).toBe(false);
    expect(capabilityNote(capsOf(UA.android))).toBe('capPhone');
    expect(capabilityNote(capsOf(UA.iphone))).toBe('capPhone');
    expect(capabilityNote(capsOf(UA.winChrome, false))).toBe('capNoScreen');
  });

  it('getDisplayMedia options: quality, sound only where possible, the studio tab left out', () => {
    const win = displayMediaOptions(capsOf(UA.winChrome), QUALITIES['1080p'], true);
    expect(win.video).toEqual({ width: { ideal: 1920 }, height: { ideal: 1080 }, frameRate: { ideal: 30, max: 30 } });
    expect(win.audio).toMatchObject({ echoCancellation: false });
    expect(win).toMatchObject({ systemAudio: 'include', selfBrowserSurface: 'exclude', surfaceSwitching: 'include' });
    const mac = displayMediaOptions(capsOf(UA.macChrome), QUALITIES['720p'], true);
    expect(mac).toMatchObject({ systemAudio: 'exclude' });
    expect(mac.audio).not.toBe(false);
    const ff = displayMediaOptions(capsOf(UA.linuxFirefox), QUALITIES['720p'], true);
    expect(ff.audio).toBe(false);
    expect(ff).not.toHaveProperty('selfBrowserSurface');
    expect(displayMediaOptions(capsOf(UA.winChrome), QUALITIES['720p'], false).audio).toBe(false);
  });
});
