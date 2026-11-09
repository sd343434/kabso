/* Kabso Live website — /i/<code> (D217, CONVENTIONS §10.71; v1.108-social D343, §10.142). Shows the code from the
 * address — a friend's invite code, or a supervisor's staff ID «Kabso07» — with «نسخ الرمز» and the download buttons
 * of config.json `apps`. The code is never sent anywhere by this page: Google Play's link carries it in `referrer` only
 * when the visitor taps it (the app reads it once with the Play Install Referrer API). No fingerprinting, no tracker,
 * no cookie; no inline script (CSP). */
(function () {
  'use strict';
  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  function all(sel) {
    return Array.prototype.slice.call(document.querySelectorAll(sel));
  }
  /** «Kabso07» (any case, leading zeros) for a staff ID, else an invite code in upper case; '' when neither. */
  function parse(path) {
    var m = /^\/i\/@?([A-Za-z0-9-]{2,20})\/?$/.exec(path);
    if (!m) return { code: '', supervisor: false };
    var raw = m[1].replace(/-/g, '');
    var staff = /^kabso0*([1-9][0-9]{0,8})?$/i.exec(raw);
    if (staff) {
      var n = staff[1] || '';
      return { code: 'Kabso' + (n === '' ? '' : n.length < 2 ? '0' + n : n), supervisor: true };
    }
    var code = raw.toUpperCase();
    return { code: /^[A-Z0-9]{6,16}$/.test(code) ? code : '', supervisor: false };
  }
  function show(sel, on) {
    all(sel).forEach(function (el) {
      el.hidden = !on;
    });
  }
  ready(function () {
    var p = parse(window.location.pathname);
    var valid = p.code !== '';
    show('[data-invite-box]', valid);
    show('[data-invite-missing]', !valid);
    show('[data-invite-title-supervisor]', p.supervisor);
    show('[data-invite-title-friend]', !p.supervisor);
    if (!valid) return;
    all('[data-invite-code]').forEach(function (el) {
      el.textContent = p.code;
    });
    all('[data-invite-copy]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var done = function () {
          var note = btn.parentNode.querySelector('[data-invite-copied]');
          if (note) note.hidden = false;
        };
        try {
          navigator.clipboard.writeText(p.code).then(done, function () {});
        } catch (e) {
          /* no clipboard: the code stays readable on the page */
        }
      });
    });
    var load = window.KABSO && window.KABSO.config ? window.KABSO.config() : Promise.resolve({});
    load.then(function (c) {
      var apps = (c && c.apps) || {};
      var links = {
        play:
          apps.playListed && /^[a-z][a-z0-9_.]{2,100}$/.test(apps.androidPackage || '')
            ? 'https://play.google.com/store/apps/details?id=' +
              encodeURIComponent(apps.androidPackage) +
              '&referrer=' +
              encodeURIComponent('kabso_code=' + p.code)
            : '',
        ios: /^https:\/\/apps\.apple\.com\//.test(apps.appStoreUrl || '') ? apps.appStoreUrl : '',
        apk: /^https:\/\//.test(apps.apkUrl || '') ? apps.apkUrl : '',
      };
      var any = false;
      all('[data-store]').forEach(function (a) {
        var href = links[a.getAttribute('data-store')] || '';
        a.hidden = href === '';
        if (href) {
          a.href = href;
          a.rel = 'noopener';
          any = true;
        }
      });
      show('[data-invite-stores]', any);
      show('[data-invite-apk-note]', links.apk !== '' || links.ios !== '');
    });
  });
})();
