/* Page titles of the legal pages (D192), per language; read by common.js. */
(function () {
  'use strict';
  var page = window.location.pathname.replace(/\.html$/, '').replace(/^\/+|\/+$/g, '');
  var TITLES = {
    privacy: ['سياسة الخصوصية', 'Privacy Policy'],
    terms: ['شروط الاستخدام', 'Terms of Service'],
    contact: ['تواصل معنا', 'Contact us'],
  };
  var t = TITLES[page];
  if (t) window.KABSO.addStrings({ ar: { pageTitle: t[0] + ' — Kabso Live' }, en: { pageTitle: t[1] + ' — Kabso Live' } });
})();
