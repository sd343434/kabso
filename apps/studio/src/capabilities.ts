/**
 * What this browser can capture (D247): honest notes for the host before they share. Browsers decide this, not
 * Kabso: Chrome / Edge on Windows (and ChromeOS) can share the system sound with a whole screen and a tab's sound with
 * a tab; Chrome / Edge on macOS and Linux share a tab's sound only; Firefox and Safari share the picture without
 * sound; phones cannot share their screen from a browser (the Android app does that, D213).
 */

export type Os = 'windows' | 'mac' | 'linux' | 'chromeos' | 'android' | 'ios' | 'other';
export type Browser = 'chrome' | 'edge' | 'opera' | 'firefox' | 'safari' | 'other';

export interface Platform {
  os: Os;
  browser: Browser;
}

export type AudioCapture = 'system-and-tab' | 'tab-only' | 'none';

export interface Capabilities extends Platform {
  /** `getDisplayMedia` exists (no phone browser has it). */
  screen: boolean;
  /** Which sound a shared screen can carry. */
  audio: AudioCapture;
  /** Chromium: the capture can switch surfaces and hide the studio's own tab. */
  chromium: boolean;
}

/** Reads the OS and browser from the user-agent string (and `userAgentData.platform` when the browser gives it). */
export function detectPlatform(userAgent: string, uaPlatform?: string): Platform {
  const ua = userAgent.toLowerCase();
  const p = (uaPlatform ?? '').toLowerCase();
  let os: Os = 'other';
  if (/android/.test(ua) || p === 'android') os = 'android';
  else if (/iphone|ipad|ipod/.test(ua) || p === 'ios') os = 'ios';
  else if (/cros/.test(ua) || p === 'chrome os' || p === 'chromeos') os = 'chromeos';
  else if (/windows/.test(ua) || p === 'windows') os = 'windows';
  else if (/mac os x|macintosh/.test(ua) || p === 'macos') os = 'mac';
  else if (/linux|x11/.test(ua) || p === 'linux') os = 'linux';

  let browser: Browser = 'other';
  if (/edg\//.test(ua)) browser = 'edge';
  else if (/opr\/|opera/.test(ua)) browser = 'opera';
  else if (/firefox\/|fxios/.test(ua)) browser = 'firefox';
  else if (/chrome\/|crios|chromium/.test(ua)) browser = 'chrome';
  else if (/safari\//.test(ua)) browser = 'safari';
  return { os, browser };
}

export function capabilitiesOf(platform: Platform, hasDisplayMedia: boolean): Capabilities {
  const chromium = platform.browser === 'chrome' || platform.browser === 'edge' || platform.browser === 'opera';
  const mobile = platform.os === 'android' || platform.os === 'ios';
  const screen = hasDisplayMedia && !mobile;
  let audio: AudioCapture = 'none';
  if (screen && chromium) {
    audio = platform.os === 'windows' || platform.os === 'chromeos' ? 'system-and-tab' : 'tab-only';
  }
  return { ...platform, screen, audio, chromium };
}

/** The current browser's capabilities. */
export function currentCapabilities(): Capabilities {
  const nav = globalThis.navigator as Navigator & { userAgentData?: { platform?: string } };
  const hasDisplayMedia = typeof nav?.mediaDevices?.getDisplayMedia === 'function';
  return capabilitiesOf(detectPlatform(nav?.userAgent ?? '', nav?.userAgentData?.platform), hasDisplayMedia);
}

/** The i18n key of the note shown under «الشاشة» for these capabilities. */
export type CapabilityNote =
  | 'capPhone'
  | 'capNoScreen'
  | 'capSystemAudio'
  | 'capMacTabAudio'
  | 'capLinuxTabAudio'
  | 'capNoAudioFirefox'
  | 'capNoAudioSafari'
  | 'capNoAudioOther';

export function capabilityNote(c: Capabilities): CapabilityNote {
  if (c.os === 'android' || c.os === 'ios') return 'capPhone';
  if (!c.screen) return 'capNoScreen';
  if (c.audio === 'system-and-tab') return 'capSystemAudio';
  if (c.audio === 'tab-only') return c.os === 'mac' ? 'capMacTabAudio' : 'capLinuxTabAudio';
  if (c.browser === 'firefox') return 'capNoAudioFirefox';
  if (c.browser === 'safari') return 'capNoAudioSafari';
  return 'capNoAudioOther';
}

/**
 * The `getDisplayMedia` options for these capabilities: sound only where the browser can give it, the studio's own
 * tab left out of the picker (a mirror of itself), switching surfaces allowed (Chromium).
 */
export function displayMediaOptions(
  c: Capabilities,
  quality: { width: number; height: number; frameRate: number },
  wantAudio: boolean,
): DisplayMediaStreamOptions & Record<string, unknown> {
  const video: MediaTrackConstraints = {
    width: { ideal: quality.width },
    height: { ideal: quality.height },
    frameRate: { ideal: quality.frameRate, max: quality.frameRate },
  };
  const audio = wantAudio && c.audio !== 'none';
  const opts: DisplayMediaStreamOptions & Record<string, unknown> = {
    video,
    audio: audio ? { echoCancellation: false, noiseSuppression: false, autoGainControl: false } : false,
  };
  if (c.chromium) {
    opts.selfBrowserSurface = 'exclude';
    opts.surfaceSwitching = 'include';
    opts.monitorTypeSurfaces = 'include';
    if (audio) opts.systemAudio = c.audio === 'system-and-tab' ? 'include' : 'exclude';
  }
  return opts;
}
