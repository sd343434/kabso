/**
 * The Kabso top-up website (v1.59-social, D190, §10.53): three small server-rendered pages — `/topup` (sign in with
 * the existing auth API, choose a package, accept the terms, go to Stripe Checkout), `/topup/success` and
 * `/topup/cancel` (the order's status, polled) — Arabic RTL by default, English with `?lang=en`. Plain HTML, CSS
 * and vanilla JS served by the API from the same origin; CSP `script-src 'self'` (no inline script runs: the page
 * data is a JSON block), no secret on the page. The access token lives in the tab's sessionStorage only.
 */
import { TOPUP_TERMS, type TopupLocale } from './topup-rules.js';

export type TopupPage = 'main' | 'success' | 'cancel';

/** The pages' strict Content-Security-Policy (no inline script, same-origin API, nothing framed). */
export const TOPUP_CSP = [
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'self'",
  "img-src 'self' data:",
  "connect-src 'self'",
  "form-action 'self'",
  "base-uri 'none'",
  "frame-ancestors 'none'",
].join('; ');

const STRINGS = {
  ar: {
    title: 'شحن عملات كابسو',
    subtitle: 'اشحن رصيدك بالبطاقة بأمان عبر Stripe',
    signInTitle: 'تسجيل الدخول',
    signInHint: 'ادخل بحساب كابسو لايف نفسه.',
    identifier: 'البريد الإلكتروني أو اسم المستخدم',
    password: 'كلمة المرور',
    signIn: 'دخول',
    signingIn: 'جارٍ الدخول…',
    signInFailed: 'البريد أو اسم المستخدم أو كلمة المرور غير صحيحة.',
    suspended: 'هذا الحساب موقوف.',
    rateLimited: 'محاولات كثيرة. حاول بعد قليل.',
    network: 'تعذّر الاتصال. حاول مجدداً.',
    signedInAs: 'الحساب',
    signOut: 'تسجيل الخروج',
    balance: 'رصيدك الحالي',
    coins: 'عملة',
    choose: 'اختر الباقة',
    terms: 'أوافق: {terms}',
    termsHint: 'لا يمكن متابعة الدفع دون الموافقة.',
    pay: 'ادفع {price}',
    payChoose: 'اختر باقة',
    redirecting: 'جارٍ تحويلك إلى صفحة الدفع…',
    secure:
      'الدفع على صفحة Stripe الآمنة مع التحقق ثلاثي الأبعاد \u20663D Secure\u2069. تصلك العملات فور تأكيد الدفع.',
    bankTransfer: 'يمكنك أيضاً اختيار التحويل البنكي في صفحة الدفع؛ تُضاف العملات عند وصول التحويل.',
    disabledTitle: 'الشحن بالبطاقة غير مفعّل',
    disabledBody: 'يمكنك الشحن عبر وكلاء الشحن من داخل التطبيق.',
    frozenTitle: 'الشراء بالبطاقة موقوف لهذا الحساب',
    frozenBody: 'بسبب استرداد أو اعتراض على عملية دفع سابقة. تواصل مع الدعم.',
    checkoutFailed: 'تعذّر بدء الدفع. حاول مجدداً.',
    statusTitle: 'حالة الدفع',
    pending: 'جارٍ تأكيد الدفع…',
    paid: 'تمت إضافة {coins} عملة إلى رصيدك.',
    reversed: 'أُلغيت هذه العملية بعد الاسترداد أو الاعتراض.',
    awaiting: 'بانتظار وصول التحويل البنكي. تُضاف العملات تلقائياً عند وصوله.',
    failed: 'لم يكتمل الدفع.',
    expired: 'انتهت مهلة الدفع ولم يُخصم أي مبلغ.',
    slow: 'ما زلنا ننتظر تأكيد Stripe. يمكنك إغلاق الصفحة؛ ستُضاف العملات عند التأكيد.',
    needSignIn: 'سجّل الدخول لرؤية حالة الطلب.',
    cancelTitle: 'أُلغي الدفع',
    cancelBody: 'لم يُخصم أي مبلغ. يمكنك المحاولة مرة أخرى.',
    back: 'العودة إلى الباقات',
    order: 'رقم الطلب',
    otherLang: 'English',
    footer: 'كابسو لايف · الدفع يتم عبر Stripe ولا نحفظ بيانات بطاقتك.',
  },
  en: {
    title: 'Kabso coins top-up',
    subtitle: 'Top up your balance by card, securely with Stripe',
    signInTitle: 'Sign in',
    signInHint: 'Use your Kabso Live account.',
    identifier: 'Email or username',
    password: 'Password',
    signIn: 'Sign in',
    signingIn: 'Signing in…',
    signInFailed: 'Wrong email, username or password.',
    suspended: 'This account is suspended.',
    rateLimited: 'Too many attempts. Try again shortly.',
    network: 'Could not connect. Try again.',
    signedInAs: 'Account',
    signOut: 'Sign out',
    balance: 'Your balance',
    coins: 'coins',
    choose: 'Choose a package',
    terms: 'I agree: {terms}',
    termsHint: 'You cannot pay without agreeing.',
    pay: 'Pay {price}',
    payChoose: 'Choose a package',
    redirecting: 'Taking you to the payment page…',
    secure:
      'You pay on Stripe’s secure page with 3D Secure. The coins arrive as soon as the payment is confirmed.',
    bankTransfer:
      'You can also choose a bank transfer on the payment page; the coins arrive when the transfer does.',
    disabledTitle: 'Card top-up is not enabled',
    disabledBody: 'You can buy coins from a recharge agent in the app.',
    frozenTitle: 'Card purchases are frozen on this account',
    frozenBody: 'Because an earlier payment was refunded or disputed. Please contact support.',
    checkoutFailed: 'Could not start the payment. Try again.',
    statusTitle: 'Payment status',
    pending: 'Confirming your payment…',
    paid: '{coins} coins were added to your balance.',
    reversed: 'This purchase was reversed after a refund or a dispute.',
    awaiting: 'Waiting for your bank transfer. The coins are added automatically when it arrives.',
    failed: 'The payment did not complete.',
    expired: 'The payment expired; nothing was charged.',
    slow: 'Still waiting for Stripe to confirm. You can close this page; the coins arrive once confirmed.',
    needSignIn: 'Sign in to see the order’s status.',
    cancelTitle: 'Payment cancelled',
    cancelBody: 'Nothing was charged. You can try again.',
    back: 'Back to the packages',
    order: 'Order',
    otherLang: 'العربية',
    footer: 'Kabso Live · Payments by Stripe; we never store your card.',
  },
} as const;

export type TopupStrings = (typeof STRINGS)[TopupLocale];

export function topupLocale(raw: unknown): TopupLocale {
  return raw === 'en' ? 'en' : 'ar';
}

function esc(text: string): string {
  return text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

/** JSON inside `<script type="application/json">`: `<` escaped so no tag can close it. */
function jsonBlock(value: unknown): string {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** One page. `orderId` (success / cancel) is echoed only when it is a UUID. */
export function renderTopupPage(page: TopupPage, lang: TopupLocale, orderId: unknown): string {
  const t = STRINGS[lang];
  const dir = lang === 'ar' ? 'rtl' : 'ltr';
  const order = typeof orderId === 'string' && UUID.test(orderId) ? orderId.toLowerCase() : null;
  const other = lang === 'ar' ? 'en' : 'ar';
  const path = page === 'main' ? '/topup' : `/topup/${page}`;
  const otherHref = `${path}?lang=${other}${order ? `&order=${order}` : ''}`;
  const data = { page, lang, order, terms: TOPUP_TERMS[lang], t };
  const main =
    page === 'main'
      ? `
    <section id="disabled" class="card notice" hidden>
      <h2>${esc(t.disabledTitle)}</h2>
      <p>${esc(t.disabledBody)}</p>
    </section>
    <section id="signin" class="card" hidden>
      <h2>${esc(t.signInTitle)}</h2>
      <p class="muted">${esc(t.signInHint)}</p>
      <form id="signin-form" novalidate>
        <label for="identifier">${esc(t.identifier)}</label>
        <input id="identifier" name="identifier" autocomplete="username" dir="ltr" required maxlength="254">
        <label for="password">${esc(t.password)}</label>
        <input id="password" name="password" type="password" autocomplete="current-password" dir="ltr" required maxlength="512">
        <p id="signin-error" class="error" role="alert" hidden></p>
        <button id="signin-button" class="primary" type="submit">${esc(t.signIn)}</button>
      </form>
    </section>
    <section id="buy" hidden>
      <div class="card account">
        <div>
          <div class="muted">${esc(t.signedInAs)}</div>
          <div id="account-name" class="strong" dir="ltr"></div>
        </div>
        <button id="signout" class="link" type="button">${esc(t.signOut)}</button>
      </div>
      <div class="card balance">
        <span class="muted">${esc(t.balance)}</span>
        <span class="coin" aria-hidden="true"></span>
        <span id="balance" class="strong" dir="ltr">—</span>
      </div>
      <section id="frozen" class="card notice danger" hidden>
        <h2>${esc(t.frozenTitle)}</h2>
        <p>${esc(t.frozenBody)}</p>
      </section>
      <section class="card">
        <h2>${esc(t.choose)}</h2>
        <div id="packages" class="grid" role="radiogroup" aria-label="${esc(t.choose)}"></div>
        <label class="terms">
          <input id="terms" type="checkbox">
          <span>${esc(t.terms.replace('{terms}', TOPUP_TERMS[lang]))}</span>
        </label>
        <p class="muted small">${esc(t.termsHint)}</p>
        <p id="buy-error" class="error" role="alert" hidden></p>
        <button id="pay" class="primary" type="button" disabled>${esc(t.payChoose)}</button>
        <p class="muted small">${esc(t.secure)}</p>
        <p id="bank-note" class="muted small" hidden>${esc(t.bankTransfer)}</p>
      </section>
    </section>`
      : page === 'success'
        ? `
    <section class="card status">
      <h2>${esc(t.statusTitle)}</h2>
      <div id="status-icon" class="status-icon pending" aria-hidden="true"></div>
      <p id="status-text" class="strong" role="status">${esc(t.pending)}</p>
      ${order ? `<p class="muted small">${esc(t.order)}: <span dir="ltr">${order}</span></p>` : ''}
      <a class="button" href="/topup?lang=${lang}">${esc(t.back)}</a>
    </section>`
        : `
    <section class="card status">
      <h2>${esc(t.cancelTitle)}</h2>
      <div class="status-icon cancel" aria-hidden="true"></div>
      <p class="strong">${esc(t.cancelBody)}</p>
      <a class="button" href="/topup?lang=${lang}">${esc(t.back)}</a>
    </section>`;
  return `<!doctype html>
<html lang="${lang}" dir="${dir}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <meta name="referrer" content="no-referrer">
  <title>${esc(t.title)}</title>
  <link rel="stylesheet" href="/topup/assets/topup.css">
</head>
<body>
  <header class="top">
    <div class="brand"><span class="logo" aria-hidden="true">K</span><span>Kabso Live</span></div>
    <a class="lang" href="${otherHref}" hreflang="${other}">${esc(t.otherLang)}</a>
  </header>
  <main>
    <h1>${esc(t.title)}</h1>
    <p class="muted">${esc(t.subtitle)}</p>${main}
  </main>
  <footer class="muted small">${esc(t.footer)}</footer>
  <script type="application/json" id="kabso-data">${jsonBlock(data)}</script>
  <script src="/topup/assets/topup.js" defer></script>
</body>
</html>
`;
}

export const TOPUP_CSS = `:root {
  --red: #e50914;
  --red-dark: #b0060f;
  --gold: #f5c451;
  --peach: #fff3e6;
  --ink: #1b1b1f;
  --muted: #6b6b76;
  --line: #ececf1;
  --page: #f7f7fa;
  --card: #ffffff;
  --danger-bg: #fdecee;
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: system-ui, -apple-system, "Segoe UI", "Noto Sans Arabic", Tahoma, Arial, sans-serif;
  background: var(--page);
  color: var(--ink);
  font-size: 16px;
  line-height: 1.5;
}
.top {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 16px; background: var(--card); border-bottom: 1px solid var(--line);
}
.brand { display: flex; align-items: center; gap: 8px; font-weight: 700; }
.logo {
  width: 28px; height: 28px; border-radius: 8px; background: var(--red); color: #fff;
  display: inline-flex; align-items: center; justify-content: center; font-weight: 800;
}
.lang { color: var(--red); text-decoration: none; font-weight: 600; font-size: 14px; }
main { max-width: 480px; margin: 0 auto; padding: 16px; }
h1 { font-size: 22px; margin: 8px 0 4px; }
h2 { font-size: 17px; margin: 0 0 8px; }
.card {
  background: var(--card); border-radius: 16px; padding: 16px; margin-top: 14px;
  box-shadow: 0 1px 3px rgba(20, 20, 40, 0.06); border: 1px solid var(--line);
}
.muted { color: var(--muted); }
.small { font-size: 13px; }
.small span[dir="ltr"] { white-space: nowrap; font-size: 12px; }
.strong { font-weight: 700; }
label { display: block; font-size: 14px; margin: 12px 0 4px; }
input[type="text"], input:not([type]), input[type="password"] {
  width: 100%; padding: 12px; font-size: 16px; border-radius: 12px; border: 1px solid #d6d6de; background: #fff;
}
input:focus { outline: 2px solid var(--red); outline-offset: 1px; }
button, .button {
  font: inherit; cursor: pointer; border: 0; border-radius: 999px; padding: 13px 18px; width: 100%;
  display: block; text-align: center; text-decoration: none; margin-top: 14px;
}
.primary { background: linear-gradient(180deg, #ff2a35, var(--red)); color: #fff; font-weight: 700; }
.primary:disabled { background: #e3e3e8; color: #9a9aa5; cursor: not-allowed; }
.button { background: var(--peach); color: var(--red-dark); font-weight: 700; }
.link { background: none; color: var(--red); width: auto; padding: 6px 0; margin: 0; font-weight: 600; }
.error { color: var(--red-dark); background: var(--danger-bg); padding: 10px 12px; border-radius: 10px; font-size: 14px; }
.account { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.balance {
  display: flex; align-items: center; gap: 8px;
  background: linear-gradient(135deg, var(--gold), #ffd9a8); border: 0;
}
.balance .muted { color: #5a4310; flex: 1; }
.coin {
  width: 22px; height: 22px; border-radius: 50%;
  background: radial-gradient(circle at 35% 35%, #fff3b8, var(--gold) 55%, #c9971f);
  box-shadow: inset 0 0 0 2px #e2ac2c;
}
.grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }
.pkg {
  margin: 0; padding: 12px 8px; border-radius: 14px; border: 2px solid var(--line); background: #fffaf4;
  color: var(--ink); display: flex; flex-direction: column; align-items: center; gap: 2px; width: 100%;
}
.pkg .amount { font-weight: 800; font-size: 17px; }
.pkg .unit { font-size: 12px; color: var(--muted); }
.pkg .price { margin-top: 4px; font-weight: 700; color: var(--red-dark); }
.pkg[aria-checked="true"] { border-color: var(--red); background: #fff1f1; }
.terms { display: flex; align-items: flex-start; gap: 10px; margin-top: 16px; font-size: 15px; font-weight: 600; }
.terms input { width: 20px; height: 20px; margin: 2px 0 0; accent-color: var(--red); flex: none; }
.notice h2 { color: var(--ink); }
.danger { background: var(--danger-bg); border-color: #f6c7cc; }
.status { text-align: center; }
.status-icon { width: 56px; height: 56px; border-radius: 50%; margin: 12px auto; position: relative; }
.status-icon.pending { border: 4px solid #f3d6d8; border-top-color: var(--red); animation: spin 1s linear infinite; }
.status-icon.ok { background: #1f9d55; }
.status-icon.ok::after {
  content: ""; position: absolute; left: 19px; top: 12px; width: 12px; height: 22px;
  border: solid #fff; border-width: 0 4px 4px 0; transform: rotate(45deg);
}
.status-icon.bad, .status-icon.cancel { background: #9a9aa5; }
.status-icon.bad::after, .status-icon.cancel::after {
  content: ""; position: absolute; left: 14px; top: 25px; width: 28px; height: 5px; background: #fff; border-radius: 3px;
}
.status-icon.wait { background: var(--gold); }
@keyframes spin { to { transform: rotate(360deg); } }
@media (prefers-reduced-motion: reduce) { .status-icon.pending { animation: none; } }
footer { text-align: center; padding: 20px 16px 28px; }
[hidden] { display: none !important; }
`;

/* The page script: plain ES5-style JS (no template literals, so it can live in this TS string). */
export const TOPUP_JS = String.raw`(function () {
  'use strict';
  var data = JSON.parse(document.getElementById('kabso-data').textContent);
  var t = data.t;
  var TOKEN = 'kabso.topup.token';
  var NAME = 'kabso.topup.name';
  var nf = new Intl.NumberFormat('en-US');
  var state = { packages: [], termsVersion: null, selected: null, frozen: false, busy: false };

  function $(id) { return document.getElementById(id); }
  function show(id, on) { var el = $(id); if (el) el.hidden = !on; }
  function read(key) { try { return window.sessionStorage.getItem(key); } catch (e) { return null; } }
  function write(key, value) {
    try { if (value === null) window.sessionStorage.removeItem(key); else window.sessionStorage.setItem(key, value); } catch (e) { /* private mode */ }
  }
  function price(minor) { return '$' + (minor / 100).toFixed(2); }
  function fill(text, key, value) { return text.split('{' + key + '}').join(value); }
  function error(id, text) { var el = $(id); if (!el) return; el.textContent = text || ''; el.hidden = !text; }

  function api(method, path, body) {
    var headers = { 'Accept': 'application/json', 'Accept-Language': data.lang };
    var token = read(TOKEN);
    if (token) headers['Authorization'] = 'Bearer ' + token;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    return fetch('/api/v1' + path, {
      method: method, headers: headers, credentials: 'omit', cache: 'no-store',
      body: body === undefined ? undefined : JSON.stringify(body)
    }).then(function (res) {
      return res.text().then(function (text) {
        var json = null;
        try { json = text ? JSON.parse(text) : null; } catch (e) { json = null; }
        return { status: res.status, body: json };
      });
    });
  }
  function code(res) { return res.body && res.body.error ? res.body.error.code : null; }

  function renderPackages() {
    var box = $('packages');
    box.textContent = '';
    state.packages.forEach(function (p) {
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'pkg';
      b.setAttribute('role', 'radio');
      b.setAttribute('aria-checked', state.selected === p.id ? 'true' : 'false');
      b.setAttribute('data-id', p.id);
      var a = document.createElement('span'); a.className = 'amount'; a.dir = 'ltr'; a.textContent = nf.format(p.coins);
      var u = document.createElement('span'); u.className = 'unit'; u.textContent = t.coins;
      var pr = document.createElement('span'); pr.className = 'price'; pr.dir = 'ltr'; pr.textContent = price(p.priceMinor);
      b.appendChild(a); b.appendChild(u); b.appendChild(pr);
      b.addEventListener('click', function () { state.selected = p.id; renderPackages(); renderPay(); });
      box.appendChild(b);
    });
  }
  function renderPay() {
    var pkg = state.packages.filter(function (p) { return p.id === state.selected; })[0];
    var pay = $('pay');
    // The price in a left-to-right isolate (an Arabic label would show "12.50$").
    pay.textContent = pkg ? fill(t.pay, 'price', '\u2066' + price(pkg.priceMinor) + '\u2069') : t.payChoose;
    pay.disabled = !pkg || !$('terms').checked || state.frozen || state.busy;
  }

  function signedOut() {
    write(TOKEN, null); write(NAME, null);
    show('buy', false); show('signin', true);
  }

  function loadMe() {
    return api('GET', '/topup/me').then(function (res) {
      if (res.status === 401) { signedOut(); return; }
      if (res.status === 503) { show('signin', false); show('buy', false); show('disabled', true); return; }
      if (res.status !== 200) { signedOut(); error('signin-error', t.network); return; }
      state.frozen = !!res.body.frozen;
      $('balance').textContent = nf.format(res.body.coins);
      $('account-name').textContent = read(NAME) || '';
      show('frozen', state.frozen);
      show('signin', false); show('buy', true);
      renderPackages(); renderPay();
    });
  }

  function initMain() {
    api('GET', '/topup/packages').then(function (res) {
      if (res.status !== 200) { show('disabled', true); return; }
      state.packages = res.body.packages;
      state.termsVersion = res.body.terms.version;
      show('bank-note', !!res.body.bankTransfer);
      if (read(TOKEN)) return loadMe();
      show('signin', true);
    }).catch(function () { show('disabled', false); show('signin', true); error('signin-error', t.network); });

    $('signin-form').addEventListener('submit', function (ev) {
      ev.preventDefault();
      var id = $('identifier').value.trim();
      var pw = $('password').value;
      if (!id || !pw) { error('signin-error', t.signInFailed); return; }
      var btn = $('signin-button');
      btn.disabled = true; btn.textContent = t.signingIn; error('signin-error', '');
      api('POST', '/auth/login', { identifier: id, password: pw, device: { platform: 'web', name: 'Kabso website' } })
        .then(function (res) {
          if (res.status === 200 && res.body && res.body.tokens) {
            write(TOKEN, res.body.tokens.accessToken);
            write(NAME, '@' + res.body.user.username);
            $('password').value = '';
            return loadMe();
          }
          var c = code(res);
          error('signin-error', c === 'RATE_LIMITED' ? t.rateLimited : c === 'ACCOUNT_SUSPENDED' ? t.suspended : t.signInFailed);
        })
        .catch(function () { error('signin-error', t.network); })
        .then(function () { btn.disabled = false; btn.textContent = t.signIn; });
    });

    $('terms').addEventListener('change', renderPay);
    $('signout').addEventListener('click', function () {
      api('POST', '/auth/logout').catch(function () { return null; }).then(signedOut);
    });
    $('pay').addEventListener('click', function () {
      if (!state.selected || !$('terms').checked) return;
      state.busy = true; renderPay(); error('buy-error', '');
      $('pay').textContent = t.redirecting;
      api('POST', '/topup/checkout', {
        packageId: state.selected, termsAccepted: true, termsVersion: state.termsVersion, locale: data.lang
      }).then(function (res) {
        if (res.status === 201 && res.body.checkoutUrl) { window.location.assign(res.body.checkoutUrl); return; }
        state.busy = false;
        var c = code(res);
        if (res.status === 401) { signedOut(); return; }
        if (c === 'TOPUP_ACCOUNT_FROZEN') { state.frozen = true; show('frozen', true); }
        else if (c === 'TOPUP_UNAVAILABLE') { show('buy', false); show('disabled', true); }
        else if (c === 'RATE_LIMITED') error('buy-error', t.rateLimited);
        else error('buy-error', t.checkoutFailed);
        renderPay();
      }).catch(function () { state.busy = false; error('buy-error', t.network); renderPay(); });
    });
  }

  function setStatus(kind, text) {
    $('status-icon').className = 'status-icon ' + kind;
    $('status-text').textContent = text;
  }
  function initSuccess() {
    if (!data.order) { setStatus('bad', t.failed); return; }
    if (!read(TOKEN)) { setStatus('wait', t.needSignIn); return; }
    var tries = 0;
    function poll() {
      tries += 1;
      api('GET', '/topup/orders/' + data.order).then(function (res) {
        if (res.status === 401) { setStatus('wait', t.needSignIn); return; }
        if (res.status !== 200) { setStatus('bad', t.failed); return; }
        var o = res.body;
        if (o.status === 'PAID' && o.coinsReversed > 0) { setStatus('bad', t.reversed); return; }
        if (o.status === 'PAID') { setStatus('ok', fill(t.paid, 'coins', nf.format(o.coins))); return; }
        if (o.status === 'AWAITING_FUNDS') { setStatus('wait', t.awaiting); return; }
        if (o.status === 'FAILED') { setStatus('bad', t.failed); return; }
        if (o.status === 'EXPIRED') { setStatus('bad', t.expired); return; }
        if (tries >= 45) { setStatus('wait', t.slow); return; }
        window.setTimeout(poll, 2000);
      }).catch(function () { if (tries < 45) window.setTimeout(poll, 3000); else setStatus('wait', t.slow); });
    }
    poll();
  }

  if (data.page === 'main') initMain();
  else if (data.page === 'success') initSuccess();
})();
`;
