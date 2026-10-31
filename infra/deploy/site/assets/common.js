/* Kabso Live website — shared by every page (D192). No inline script anywhere (CSP script-src 'self').
 * Loaded in <head> without defer: it sets <html lang/dir> before the first paint, then wires the page once the
 * DOM is ready. Language: ?lang=en|ar, else the visitor's last choice (localStorage, wrapped in try/catch), else
 * Arabic. The website's settings (footer social links, the top-up switch) come from the API's public
 * GET /api/v1/site/settings, kept 5 minutes in sessionStorage; on any error the icons stay hidden and the top-up
 * link stays off. The legal fields come from config.json. */
(function () {
  'use strict';
  var LANG_KEY = 'kabso.lang';
  var SETTINGS_KEY = 'kabso.siteSettings.v1';
  var SETTINGS_TTL = 5 * 60 * 1000;

  function store(kind) {
    try {
      return kind === 'local' ? window.localStorage : window.sessionStorage;
    } catch (e) {
      return null;
    }
  }
  function read(kind, key) {
    try {
      var s = store(kind);
      return s ? s.getItem(key) : null;
    } catch (e) {
      return null;
    }
  }
  function write(kind, key, value) {
    try {
      var s = store(kind);
      if (s) s.setItem(key, value);
    } catch (e) {
      /* private mode, blocked storage: the page works without it */
    }
  }

  function queryLang() {
    try {
      var v = new URLSearchParams(window.location.search).get('lang');
      return v === 'en' || v === 'ar' ? v : null;
    } catch (e) {
      return null;
    }
  }

  var fromQuery = queryLang();
  var stored = read('local', LANG_KEY);
  var lang = fromQuery || (stored === 'en' || stored === 'ar' ? stored : 'ar');
  if (fromQuery) write('local', LANG_KEY, fromQuery);

  var root = document.documentElement;
  function applyDir() {
    root.lang = lang;
    root.dir = lang === 'ar' ? 'rtl' : 'ltr';
  }
  applyDir();

  var listeners = [];
  var dicts = {};

  /** Strings shared by every page (header, footer, banner). Pages add their own with K.addStrings. */
  var COMMON = {
    ar: {
      toggle: 'EN',
      toggleLabel: 'Switch to English',
      topup: 'شحن العملات',
      privacy: 'الخصوصية',
      terms: 'الشروط',
      contact: 'تواصل معنا',
      home: 'الرئيسية',
      soon: 'سيُضاف قريباً',
      draft: 'مسودة — تحتاج مراجعة قانونية',
      instagram: 'كابسو على إنستغرام',
      tiktok: 'كابسو على تيك توك',
      whatsapp: 'كابسو على واتساب',
    },
    en: {
      toggle: 'عربي',
      toggleLabel: 'التبديل إلى العربية',
      topup: 'Top up coins',
      privacy: 'Privacy',
      terms: 'Terms',
      contact: 'Contact',
      home: 'Home',
      soon: 'To be added soon',
      draft: 'Draft — pending legal review',
      instagram: 'Kabso on Instagram',
      tiktok: 'Kabso on TikTok',
      whatsapp: 'Kabso on WhatsApp',
    },
  };

  function t(key) {
    var d = dicts[lang] || {};
    if (Object.prototype.hasOwnProperty.call(d, key)) return d[key];
    var c = COMMON[lang] || {};
    return Object.prototype.hasOwnProperty.call(c, key) ? c[key] : '';
  }

  /** Text of [data-i18n]; [data-i18n-html] for strings with <b> only (our own constant strings, never input). */
  function translate() {
    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) nodes[i].textContent = t(nodes[i].getAttribute('data-i18n'));
    nodes = document.querySelectorAll('[data-i18n-html]');
    for (i = 0; i < nodes.length; i++) nodes[i].innerHTML = t(nodes[i].getAttribute('data-i18n-html'));
    nodes = document.querySelectorAll('[data-i18n-placeholder]');
    for (i = 0; i < nodes.length; i++) nodes[i].placeholder = t(nodes[i].getAttribute('data-i18n-placeholder'));
    nodes = document.querySelectorAll('[data-i18n-aria]');
    for (i = 0; i < nodes.length; i++) nodes[i].setAttribute('aria-label', t(nodes[i].getAttribute('data-i18n-aria')));
    // Bilingual blocks (the legal texts): only the current language is shown.
    nodes = document.querySelectorAll('[data-lang]');
    for (i = 0; i < nodes.length; i++) nodes[i].hidden = nodes[i].getAttribute('data-lang') !== lang;
    var title = t('pageTitle');
    if (title) document.title = title;
    // Internal links keep the language even when storage is blocked.
    nodes = document.querySelectorAll('a[data-internal]');
    for (i = 0; i < nodes.length; i++) {
      var base = nodes[i].getAttribute('data-internal');
      nodes[i].setAttribute('href', lang === 'en' ? base + '?lang=en' : base);
    }
  }

  function setLang(next) {
    if (next !== 'ar' && next !== 'en') return;
    lang = next;
    write('local', LANG_KEY, next);
    applyDir();
    try {
      var url = new URL(window.location.href);
      if (next === 'en') url.searchParams.set('lang', 'en');
      else url.searchParams.delete('lang');
      window.history.replaceState(null, '', url.pathname + url.search + url.hash);
    } catch (e) {
      /* old browser: the language still changes */
    }
    translate();
    for (var i = 0; i < listeners.length; i++) listeners[i](lang);
  }

  function getJson(url) {
    return fetch(url, { credentials: 'omit', headers: { Accept: 'application/json' } }).then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    });
  }

  var HOSTS = {
    instagram: /^https:\/\/www\.instagram\.com\/[A-Za-z0-9._]{1,30}$/,
    tiktok: /^https:\/\/www\.tiktok\.com\/@[A-Za-z0-9._]{2,24}$/,
    whatsapp: /^https:\/\/wa\.me\/[1-9][0-9]{7,14}$/,
  };

  /** Only links of the expected shape are used, whatever the server sent. */
  function cleanSettings(s) {
    var out = { socials: {}, topupEnabled: false };
    if (!s || typeof s !== 'object') return out;
    var socials = s.socials && typeof s.socials === 'object' ? s.socials : {};
    for (var k in HOSTS) {
      if (typeof socials[k] === 'string' && HOSTS[k].test(socials[k])) out.socials[k] = socials[k];
    }
    out.topupEnabled = s.topupEnabled === true;
    return out;
  }

  function loadSettings() {
    var cached = read('session', SETTINGS_KEY);
    if (cached) {
      try {
        var c = JSON.parse(cached);
        if (c && typeof c.at === 'number' && Date.now() - c.at < SETTINGS_TTL) {
          return Promise.resolve(cleanSettings(c.value));
        }
      } catch (e) {
        /* ignore a broken cache */
      }
    }
    return getJson('/api/v1/site/settings').then(
      function (value) {
        write('session', SETTINGS_KEY, JSON.stringify({ at: Date.now(), value: value }));
        return cleanSettings(value);
      },
      function () {
        return cleanSettings(null);
      },
    );
  }

  var configPromise = null;
  function loadConfig() {
    if (!configPromise) {
      configPromise = getJson('/config.json').then(
        function (c) {
          return c && typeof c === 'object' ? c : {};
        },
        function () {
          return {};
        },
      );
    }
    return configPromise;
  }

  var SVG_NS = 'http://www.w3.org/2000/svg';
  var ICONS = {
    instagram:
      'M12 2.2c3.2 0 3.6 0 4.8.1 1.2.1 1.8.2 2.2.4.6.2 1 .5 1.4.9.4.4.7.8.9 1.4.2.4.4 1 .4 2.2.1 1.3.1 1.6.1 4.8s0 3.6-.1 4.8c-.1 1.2-.2 1.8-.4 2.2-.2.6-.5 1-.9 1.4-.4.4-.8.7-1.4.9-.4.2-1 .4-2.2.4-1.3.1-1.6.1-4.8.1s-3.6 0-4.8-.1c-1.2-.1-1.8-.2-2.2-.4-.6-.2-1-.5-1.4-.9-.4-.4-.7-.8-.9-1.4-.2-.4-.4-1-.4-2.2C2.2 15.6 2.2 15.2 2.2 12s0-3.6.1-4.8c.1-1.2.2-1.8.4-2.2.2-.6.5-1 .9-1.4.4-.4.8-.7 1.4-.9.4-.2 1-.4 2.2-.4C8.4 2.2 8.8 2.2 12 2.2zm0 2c-3.1 0-3.5 0-4.7.1-1.1.1-1.7.2-2.1.4-.5.2-.9.4-1.2.8-.4.4-.6.7-.8 1.2-.2.4-.3 1-.4 2.1-.1 1.2-.1 1.6-.1 4.7s0 3.5.1 4.7c.1 1.1.2 1.7.4 2.1.2.5.4.9.8 1.2.4.4.7.6 1.2.8.4.2 1 .3 2.1.4 1.2.1 1.6.1 4.7.1s3.5 0 4.7-.1c1.1-.1 1.7-.2 2.1-.4.5-.2.9-.4 1.2-.8.4-.4.6-.7.8-1.2.2-.4.3-1 .4-2.1.1-1.2.1-1.6.1-4.7s0-3.5-.1-4.7c-.1-1.1-.2-1.7-.4-2.1-.2-.5-.4-.9-.8-1.2-.4-.4-.7-.6-1.2-.8-.4-.2-1-.3-2.1-.4-1.2-.1-1.6-.1-4.7-.1zm0 3.1a4.7 4.7 0 1 1 0 9.4 4.7 4.7 0 0 1 0-9.4zm0 7.7a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm4.9-8.9a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 0 1 0-2.2z',
    tiktok:
      'M16.6 2h-3.3v13.2a2.9 2.9 0 1 1-2.9-2.9c.3 0 .6 0 .8.1V9a6.2 6.2 0 1 0 5.4 6.2V8.4a7.8 7.8 0 0 0 4.4 1.4V6.5a4.5 4.5 0 0 1-4.4-4.5z',
    whatsapp:
      'M12 2a9.9 9.9 0 0 0-8.5 15l-1.4 5 5.1-1.3A9.9 9.9 0 1 0 12 2zm0 18.1c-1.5 0-3-.4-4.3-1.2l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.1zm4.5-6.1c-.2-.1-1.5-.7-1.7-.8-.2-.1-.4-.1-.6.1l-.8 1c-.1.2-.3.2-.5.1-.7-.3-1.5-.7-2.3-1.6-.6-.5-1-1.2-1.1-1.4-.1-.2 0-.4.1-.5l.4-.4.2-.4v-.4l-.8-1.9c-.2-.5-.4-.4-.6-.4h-.5c-.2 0-.4.1-.6.3-.2.2-.8.8-.8 2s.8 2.3.9 2.5c.1.2 1.6 2.5 4 3.5 1.5.6 2 .7 2.8.6.5-.1 1.5-.6 1.7-1.2.2-.6.2-1.1.2-1.2-.1-.1-.3-.2-.5-.3z',
  };

  function icon(name) {
    var svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');
    var path = document.createElementNS(SVG_NS, 'path');
    path.setAttribute('fill', 'currentColor');
    path.setAttribute('d', ICONS[name]);
    svg.appendChild(path);
    return svg;
  }

  /** Fills every [data-socials] container with the links set (none: the container stays empty and hidden). */
  function renderSocials(settings) {
    var boxes = document.querySelectorAll('[data-socials]');
    for (var b = 0; b < boxes.length; b++) {
      var box = boxes[b];
      while (box.firstChild) box.removeChild(box.firstChild);
      var withLabels = box.hasAttribute('data-labels');
      var any = false;
      ['instagram', 'tiktok', 'whatsapp'].forEach(function (name) {
        var url = settings.socials[name];
        if (!url) return;
        any = true;
        var a = document.createElement('a');
        a.href = url;
        a.target = '_blank';
        a.rel = 'noopener noreferrer';
        a.className = 'social social-' + name;
        a.setAttribute('data-i18n-aria', name);
        a.setAttribute('aria-label', t(name));
        a.appendChild(icon(name));
        if (withLabels) {
          var span = document.createElement('span');
          span.setAttribute('data-i18n', name);
          span.textContent = t(name);
          a.appendChild(span);
        }
        box.appendChild(a);
      });
      box.hidden = !any;
      var item = box.closest('[data-socials-item]');
      if (item) item.hidden = !any;
    }
  }

  function renderTopup(settings) {
    var links = document.querySelectorAll('[data-topup]');
    for (var i = 0; i < links.length; i++) {
      links[i].href = window.location.origin + '/topup';
      links[i].hidden = !settings.topupEnabled;
    }
  }

  function wireToggle() {
    var buttons = document.querySelectorAll('[data-lang-toggle]');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].addEventListener('click', function () {
        setLang(lang === 'ar' ? 'en' : 'ar');
      });
    }
  }

  function setYear() {
    var nodes = document.querySelectorAll('[data-year]');
    for (var i = 0; i < nodes.length; i++) nodes[i].textContent = String(new Date().getFullYear());
  }

  var settingsPromise = null;

  window.KABSO = {
    lang: function () {
      return lang;
    },
    t: t,
    addStrings: function (more) {
      for (var l in more) {
        dicts[l] = dicts[l] || {};
        for (var k in more[l]) dicts[l][k] = more[l][k];
      }
    },
    onLang: function (fn) {
      listeners.push(fn);
    },
    translate: translate,
    config: loadConfig,
    settings: function () {
      return settingsPromise || (settingsPromise = loadSettings());
    },
  };

  function ready() {
    translate();
    wireToggle();
    setYear();
    window.KABSO.settings().then(function (s) {
      renderSocials(s);
      renderTopup(s);
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ready);
  else ready();
})();
