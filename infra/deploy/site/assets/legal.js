/* Kabso Live legal pages (D192): fills the legal entity and contact from /config.json. An empty field shows
 * «سيُضاف قريباً» / "To be added soon"; on /contact an item whose field is empty is left out; the draft banner shows
 * until config.legalReviewed is true (and whenever config.json cannot be read). */
(function () {
  'use strict';
  var K = window.KABSO;
  var cfg = null;

  function value(key) {
    if (!cfg) return '';
    var v = cfg[key];
    return typeof v === 'string' ? v.trim() : typeof v === 'number' ? String(v) : '';
  }

  function render() {
    var nodes = document.querySelectorAll('[data-cfg]');
    for (var i = 0; i < nodes.length; i++) {
      var v = value(nodes[i].getAttribute('data-cfg'));
      nodes[i].textContent = v || K.t('soon');
      nodes[i].classList.toggle('missing', !v);
    }
    nodes = document.querySelectorAll('a[data-cfg-mail]');
    for (i = 0; i < nodes.length; i++) {
      var mail = value(nodes[i].getAttribute('data-cfg-mail'));
      if (mail && /^[^\s@<>"]+@[^\s@<>"]+$/.test(mail)) {
        nodes[i].href = 'mailto:' + mail;
        nodes[i].textContent = mail;
        nodes[i].classList.remove('missing');
      } else {
        nodes[i].removeAttribute('href');
        nodes[i].textContent = K.t('soon');
        nodes[i].classList.add('missing');
      }
    }
    nodes = document.querySelectorAll('[data-cfg-item]');
    for (i = 0; i < nodes.length; i++) nodes[i].hidden = !value(nodes[i].getAttribute('data-cfg-item'));
    var banner = document.getElementById('draft');
    if (banner) banner.hidden = !!(cfg && cfg.legalReviewed === true);
  }

  K.onLang(render);
  document.addEventListener('DOMContentLoaded', function () {
    render();
    K.config().then(function (c) {
      cfg = c;
      render();
    });
  });
})();
