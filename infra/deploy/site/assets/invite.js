/* Kabso Live website — /i/<code> (D217, CONVENTIONS §10.71). Shows the invite code from the address with a copy
 * button; the code is never sent anywhere (the person types or pastes it in the app). No inline script (CSP). */
(function () {
  'use strict';
  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }
  ready(function () {
    var m = /^\/i\/([A-Za-z0-9-]{6,20})\/?$/.exec(window.location.pathname);
    var code = m ? m[1].replace(/-/g, '').toUpperCase() : '';
    var valid = /^[A-Z0-9]{6,16}$/.test(code);
    document.querySelectorAll('[data-invite-box]').forEach(function (box) {
      box.hidden = !valid;
    });
    document.querySelectorAll('[data-invite-missing]').forEach(function (el) {
      el.hidden = valid;
    });
    if (!valid) return;
    document.querySelectorAll('[data-invite-code]').forEach(function (el) {
      el.textContent = code;
    });
    document.querySelectorAll('[data-invite-copy]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var done = function () {
          var note = btn.parentNode.querySelector('[data-invite-copied]');
          if (note) note.hidden = false;
        };
        try {
          navigator.clipboard.writeText(code).then(done, function () {});
        } catch (e) {
          /* no clipboard: the code stays readable on the page */
        }
      });
    });
  });
})();
