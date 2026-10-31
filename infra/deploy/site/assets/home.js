/* Kabso Live coming-soon page — the owner's show (D192). The stage, the moves, the spotlight, the particles and the
 * loop are the owner's script unchanged; D192 changed only: the art comes from assets/ (no base64), each character
 * speaks Arabic or English with the page, the store buttons became the waitlist form + «قريباً» badges, and the
 * form's states. */
(function () {
  'use strict';
  var K = window.KABSO;

  K.addStrings({
    ar: {
      pageTitle: 'Kabso Live — قريباً',
      h1: 'قريباً',
      sub: '<b>عائلة كابسو</b> تجهّز للبث الكبير…',
      tagline: 'Coming soon · Live · Reels · Podcast',
      email: 'بريدك الإلكتروني',
      emailLabel: 'بريدك الإلكتروني لنبلغك عند الإطلاق',
      notify: 'أبلغني عند الإطلاق',
      sending: 'جارٍ الإرسال…',
      note: 'نستخدم بريدك فقط لإبلاغك بالإطلاق.',
      ok: 'تم! سنراسلك فور الإطلاق 🎉',
      invalid: 'اكتب بريداً إلكترونياً صحيحاً',
      limited: 'محاولات كثيرة — جرّب بعد قليل',
      failed: 'تعذّر الإرسال، حاول مرة أخرى',
      soonOn: 'قريباً',
    },
    en: {
      pageTitle: 'Kabso Live — Coming soon',
      h1: 'Coming soon',
      sub: '<b>The Kabso family</b> is getting ready for the big show…',
      tagline: 'Live · Reels · Podcast',
      email: 'Your email',
      emailLabel: 'Your email, to hear from us at launch',
      notify: 'Notify me at launch',
      sending: 'Sending…',
      note: 'We only use your email to tell you about the launch.',
      ok: "You're on the list! We'll email you at launch 🎉",
      invalid: 'Please enter a valid email',
      limited: 'Too many tries — please try again later',
      failed: "Couldn't send — please try again",
      soonOn: 'Coming soon',
    },
  });

  var A = 'assets/characters/';
  var IMG = [
      A + 'seed.webp',
      A + 'bunny.webp',
      A + 'kitty.webp',
      A + 'butterfly.webp',
      A + 'fox.webp',
      A + 'owl.webp',
      A + 'unicorn.webp',
      A + 'dragon.webp',
      A + 'phoenix.webp',
      A + 'king-kabi.webp',
    ],
    INFO = {"1": {"w": 433, "h": 540, "ex": 217.2, "ey": 245.4, "feet": 533.4}, "2": {"w": 349, "h": 567, "ex": 156.4, "ey": 263.3, "feet": 563.3}, "3": {"w": 444, "h": 545, "ex": 190.3, "ey": 166.1, "feet": 532.1}, "4": {"w": 606, "h": 525, "ex": 302.5, "ey": 227.9, "feet": 521.9}, "5": {"w": 488, "h": 518, "ex": 171.8, "ey": 239.5, "feet": 509.5}, "6": {"w": 502, "h": 515, "ex": 252.3, "ey": 189.5, "feet": 507.5}, "7": {"w": 538, "h": 578, "ex": 258.6, "ey": 264.3, "feet": 564.3}, "8": {"w": 568, "h": 518, "ex": 280.1, "ey": 202.3, "feet": 502.3}, "9": {"w": 654, "h": 593, "ex": 322.1, "ey": 287.8, "feet": 587.8}, "10": {"w": 618, "h": 557, "ex": 307.2, "ey": 256.3, "feet": 556.3}};
  // n / l: the owner's Arabic; en / le: the English version.
  var C = [
    {n:'بذرة',en:'Sprout',c:'#7BE08F',m:'grow',fx:'leaf',l:['أنا صغير بس طموحي كبير 🌱','سقّوني… أنا بكبر!','بذرة اليوم، نجم بكرة ✨'],le:["I'm small, but my dreams are big 🌱",'Water me… I’m growing!','A seed today, a star tomorrow ✨']},
    {n:'أرنوبة',en:'Bunny',c:'#FF8FC0',m:'hop',fx:'heart',l:['نط نط… قريباً قريباً! 🐰','قلبي بيدق من الحماس 💗','مين جاهز؟ أنا!'],le:['Hop hop… coming soon! 🐰','My heart’s racing with excitement 💗',"Who's ready? Me!"]},
    {n:'قطقوطة',en:'Kitty',c:'#FFA060',m:'wave',fx:'bell',l:['مياو… جرس الإطلاق رنّ 🔔','جبتلكم الحظ 🍀','ميااو قريباً!'],le:['Meow… the launch bell just rang 🔔','I brought you luck 🍀','Meeeow, coming soon!']},
    {n:'فراشة',en:'Butterfly',c:'#C89BFF',m:'flutter',fx:'spark',l:['طايرة من الفرحة 🦋','خفيفة… وقريبة!','رفرفة قبل البث ✨'],le:['Flying with joy 🦋','Light as air… and almost here!','One flutter before we go live ✨']},
    {n:'ثعلوب',en:'Foxy',c:'#FF8A2A',m:'spin',fx:'leaf2',l:['أسرع واحد بالفريق 🦊','لفّة قبل الإطلاق!','ذكي وجاهز 😎'],le:['Fastest on the team 🦊','A spin before launch!','Clever and ready 😎']},
    {n:'بومة',en:'Owl',c:'#6FA4FF',m:'flap',fx:'feather',l:['سهرانة أجهّز البث 🦉','هووو… قرّبنا!','عيوني على الإطلاق 👀'],le:['Up all night getting the stream ready 🦉','Hoooo… we’re almost there!','Eyes on the launch 👀']},
    {n:'يونيكورن',en:'Unicorn',c:'#E08CFF',m:'prance',fx:'rainbow',l:['قوس قزح جاهز 🌈','سحر قريباً ✨','أنا مميّز… وأنت كمان'],le:['The rainbow is ready 🌈','Magic, coming soon ✨','I’m one of a kind… and so are you']},
    {n:'تنين',en:'Dragon',c:'#FF3B3B',m:'sneeze',fx:'fire',l:['هاتشوو 🔥 آسف… متحمّس!','ما قصدت أحرق شي 😅','ناااار قريباً'],le:['Achoo 🔥 sorry… just excited!','I didn’t mean to burn anything 😅','Fiiire, coming soon']},
    {n:'عنقاء',en:'Phoenix',c:'#FF9A1A',m:'blaze',fx:'ember',l:['ولّعت الحماس 🔥','من الرماد للقمة!','حار حار قريباً'],le:['I set the excitement on fire 🔥','From the ashes to the top!','Hot, hot… coming soon']},
    {n:'الملك كابي',en:'King Kabi',c:'#FFC83C',m:'royal',fx:'gold',l:['الملك وصل 👑 قريباً!','كاب كاب كابسووو!','جهّزوا التاج… والبث'],le:['The king has arrived 👑 coming soon!','Kab kab Kabsooo!','Polish the crown… and the stream']}];
  var en = function () {
    return K.lang() === 'en';
  };

  var root = document.documentElement,
    stage = document.getElementById('stage'),
    spot = document.getElementById('spot');
  var CH = C.map(function (c, i) {
    var d = document.createElement('div');
    d.className = 'ch k' + (i + 1);
    d.style.setProperty('--c', c.c);
    d.style.setProperty('--d', -i * 0.37 + 's');
    d.innerHTML =
      '<div class="mv"><div class="br">' +
      (i == 9 ? '<div class="rays"></div>' : '') +
      '<div class="sh"></div><img src="' +
      IMG[i] +
      '" alt="" draggable="false" decoding="async" width="' +
      INFO[i + 1].w +
      '" height="' +
      INFO[i + 1].h +
      '"><div class="rf"><img src="' +
      IMG[i] +
      '" alt="" decoding="async"></div></div></div><div class="bub"></div>';
    d.querySelector('img').alt = en() ? c.en : c.n;
    stage.appendChild(d);
    d.addEventListener('click', function () {
      perform(i, true);
      if (i == 9) play();
    });
    return d;
  });
  K.onLang(function () {
    CH.forEach(function (el, i) {
      el.querySelector('img').alt = en() ? C[i].en : C[i].n;
      var b = el.querySelector('.bub');
      if (b.classList.contains('on')) b.textContent = pick(C[i]);
    });
  });
  function pick(c) {
    var lines = en() ? c.le : c.l;
    return lines[(Math.random() * lines.length) | 0];
  }
  var L = [],
    cur = 0,
    compact = false,
    prevK = [];
  function place(i, cx, yFeet, s2, z) {
    var d = INFO[i + 1],
      el = CH[i];
    el.style.width = d.w * s2 + 'px';
    el.style.height = d.h * s2 + 'px';
    el.style.left = cx - d.ex * s2 + 'px';
    el.style.top = yFeet - d.feet * s2 + 'px';
    el.style.zIndex = z;
    L[i] = { cx: cx, y: yFeet - d.ey * s2, sc: s2 };
  }
  var badges = document.getElementById('badges');
  function layout() {
    var w = innerWidth,
      h = innerHeight,
      mob = w < 700;
    root.classList.toggle('mob', mob);
    root.classList.toggle('vsm', w < 375);
    var fh = mob ? h * 0.4 : h * 0.3;
    root.style.setProperty('--fh', fh + 'px');
    if (!mob) {
      var span = Math.min(w * 0.9, 1500),
        gap = span / 10,
        sc = Math.min(gap / 360, (h * 0.26) / 440),
        y = h - fh * 0.42;
      for (var i = 0; i < 10; i++) place(i, w / 2 - span / 2 + gap * (i + 0.5), y, sc, 20 + (i % 2 ? 1 : 3));
      root.style.setProperty('--sw', Math.min((w / 10) * 1.5, 260) + 'px');
    } else if (compact) {
      var gap2 = (w - 30) / 10,
        sc2 = (gap2 * 1.3) / 300,
        y2 = h - fh * 0.45; // group photo: all 10 in one row
      for (var j = 0; j < 10; j++) {
        CH[j].classList.add('slide');
        place(j, w / 2 + (j - 4.5) * gap2, y2, sc2, 20 + (j % 2 ? 1 : 3));
      }
      root.style.setProperty('--sw', w * 1.2 + 'px');
    } else {
      var gap3 = w * 0.42,
        sc3 = Math.min(gap3 / 330, (h * 0.3) / 440),
        y3 = h - fh * 0.4; // parade: one in the spotlight, neighbours peeking
      for (var k = 0; k < 10; k++) {
        var kk = ((k - cur + 15) % 10) - 5,
          el = CH[k];
        if (prevK[k] !== undefined && Math.abs(prevK[k] - kk) > 1) el.classList.remove('slide');
        else el.classList.add('slide');
        prevK[k] = kk;
        place(k, w / 2 + kk * gap3, y3, sc3, kk == 0 ? 30 : 20 - Math.abs(kk));
        void el.offsetWidth;
      }
      root.style.setProperty('--sw', w * 0.5 + 'px');
    }
    // D192: the waitlist form always shows; the small store badges only where there is room — on a phone, never
    // under the speech bubble of the character in the spotlight.
    badges.hidden = false;
    var top = function (n) {
      return L[n].y + (INFO[n + 1].ey - INFO[n + 1].feet) * L[n].sc;
    };
    var room = mob ? top(cur) : Math.min.apply(null, L.map(function (_, n) { return top(n); }));
    room -= 52; // the speech bubble above a character
    badges.hidden = h < 600 || badges.getBoundingClientRect().bottom > room;
  }
  var isMob = function () {
    return innerWidth < 700;
  };
  layout();
  addEventListener('resize', layout);
  var voice = document.getElementById('voice');
  function play() {
    try {
      voice.currentTime = 0;
      var p = voice.play();
      if (p && p.catch) p.catch(function () {});
    } catch (e) {
      /* no audio */
    }
  }
  var busy = new Set();
  function perform(i, user) {
    var el = CH[i],
      mv = el.querySelector('.mv'),
      c = C[i];
    if (busy.has(i) && !user) return;
    busy.add(i);
    mv.className = 'mv';
    void mv.offsetWidth;
    mv.classList.add('m-' + c.m);
    el.classList.add('lit');
    root.style.setProperty('--glow', c.c);
    spot.style.left = L[i].cx + 'px';
    spot.classList.add('on');
    var b = el.querySelector('.bub');
    b.textContent = pick(c);
    b.classList.add('on');
    var t0 = performance.now();
    var iv = setInterval(function () {
      fx(i);
      if (performance.now() - t0 > 1100) clearInterval(iv);
    }, 90);
    if (i == 9)
      setTimeout(function () {
        bigBurst(L[9].cx, L[9].y, 'gold');
      }, 500);
    setTimeout(function () {
      b.classList.remove('on');
      mv.className = 'mv';
      busy.delete(i);
      if (user) el.classList.remove('lit');
    }, 2200);
  }
  // show: intro pop-in → spotlight journey seed→king → finale → repeat
  var W = function (ms) {
    return new Promise(function (r) {
      setTimeout(r, ms);
    });
  };
  async function show() {
    for (let i = 0; i < 10; i++) {
      CH[i].classList.add('show');
      const mv = CH[i].querySelector('.mv');
      mv.classList.add('m-jump');
      setTimeout(() => mv.classList.remove('m-jump'), 800);
      await W(110);
    }
    await W(900);
    while (true) {
      for (let i = 0; i < 10; i++) {
        if (isMob()) {
          cur = i;
          layout();
          await W(750);
        }
        perform(i);
        await W(i == 9 ? 2600 : 2300);
      }

      document.body.classList.add('finale');
      spot.style.left = innerWidth / 2 + 'px';
      for (let k = 0; k < 10; k++)
        setTimeout(() => {
          const mv = CH[k].querySelector('.mv');
          mv.style.setProperty('--rot', (k % 2 ? -8 : 8) + 'deg');
          mv.className = 'mv';
          void mv.offsetWidth;
          mv.classList.add('m-jump');
          CH[k].classList.add('lit');
        }, k * 110);
      confetti();
      setTimeout(confetti, 900);
      await W(3200);
      document.body.classList.remove('finale');
      spot.classList.remove('on');
      CH.forEach((e) => e.classList.remove('lit'));
      root.style.setProperty('--glow', '#FF2A36');
      await W(1500);
    }
  }
  // particles
  var cv = document.getElementById('fx'),
    g = cv.getContext('2d');
  var CW,
    CHh,
    Q = [];
  var dpr = Math.min(devicePixelRatio, 2);
  function rs() {
    CW = cv.width = innerWidth * dpr;
    CHh = cv.height = innerHeight * dpr;
    cv.style.width = innerWidth + 'px';
    cv.style.height = innerHeight + 'px';
  }
  rs();
  addEventListener('resize', rs);
  var RM = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var R = function (a, b) {
    return a + Math.random() * (b - a);
  };
  function fx(i) {
    if (RM) return;
    var p = L[i],
      s = p.sc * dpr,
      x = p.cx * dpr,
      y = p.y * dpr,
      t = C[i].fx;
    var add = function (o) {
      Q.push(Object.assign({ l: 1, r: 0, vr: R(-0.1, 0.1), g: 0.12 }, o));
    };
    if (t == 'leaf' || t == 'leaf2')
      add({ x: x + R(-60, 60) * s, y: y - R(40, 120) * s, vx: R(-2, 2) * dpr, vy: R(-3, -1) * dpr, k: 'leaf', c: t == 'leaf' ? '#5CCB5F' : '#FF8A2A', z: R(8, 13) * dpr, g: 0.05 });
    if (t == 'heart')
      add({ x: x + R(-50, 50) * s, y: y - R(60, 140) * s, vx: R(-1, 1) * dpr, vy: R(-3, -1.5) * dpr, k: 'heart', c: Math.random() < 0.5 ? '#FF5C9A' : '#FFB3CF', z: R(9, 14) * dpr, g: -0.02 });
    if (t == 'bell' || t == 'spark' || t == 'gold' || t == 'rainbow') {
      var cols = t == 'rainbow' ? ['#FF5C6C', '#FFB23A', '#FFE14A', '#5CD67A', '#4FA3FF', '#A57BFF'] : t == 'spark' ? ['#E7C6FF', '#FFB3E6', '#fff'] : ['#FFD24A', '#fff'];
      add({ x: x + R(-110, 110) * s, y: y + R(-200, 40) * s, vx: R(-1.5, 1.5) * dpr, vy: R(-2.5, -0.5) * dpr, k: 'star', c: cols[(Math.random() * cols.length) | 0], z: R(6, 11) * dpr, g: 0.02 });
    }
    if (t == 'feather')
      add({ x: x + R(-90, 90) * s, y: y + R(-40, 60) * s, vx: R(-2, 2) * dpr, vy: R(-2, 0) * dpr, k: 'leaf', c: '#8DB8FF', z: R(8, 12) * dpr, g: 0.03 });
    if (t == 'fire')
      for (var j = 0; j < 3; j++)
        add({ x: x - 40 * s, y: y + 40 * s, vx: R(-9, -5) * dpr, vy: R(-1.5, 1) * dpr, k: 'dot', c: ['#FFE14A', '#FF8A00', '#FF3B1F'][j], z: R(7, 14) * dpr, g: -0.04 });
    if (t == 'ember')
      for (var e = 0; e < 2; e++)
        add({ x: x + R(-120, 120) * s, y: y + R(-60, 120) * s, vx: R(-1, 1) * dpr, vy: R(-5, -2) * dpr, k: 'dot', c: Math.random() < 0.5 ? '#FFC23A' : '#FF6A00', z: R(3, 6) * dpr, g: -0.03 });
  }
  function bigBurst(cx, cy) {
    if (RM) return;
    for (var j = 0; j < 70; j++) {
      var a = R(0, 6.28),
        v = R(3, 10) * dpr;
      Q.push({ x: cx * dpr, y: cy * dpr, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 3 * dpr, l: 1.3, k: 'star', c: Math.random() < 0.6 ? '#FFD24A' : '#fff', z: R(6, 12) * dpr, g: 0.15, r: 0, vr: 0.1 });
    }
  }
  function confetti() {
    if (RM) return;
    var cols = C.map(function (c) {
      return c.c;
    });
    for (var j = 0; j < 140; j++)
      Q.push({ x: R(0, CW), y: R(-CHh * 0.3, -10), vx: R(-1.5, 1.5) * dpr, vy: R(2, 6) * dpr, l: 2.2, k: 'conf', c: cols[j % 10], z: R(6, 11) * dpr, g: 0.04, r: R(0, 6), vr: R(-0.2, 0.2) });
  }
  function heart(x, y, z) {
    g.beginPath();
    g.moveTo(x, y + z * 0.35);
    g.bezierCurveTo(x + z, y - z * 0.4, x + z * 0.5, y - z, x, y - z * 0.45);
    g.bezierCurveTo(x - z * 0.5, y - z, x - z, y - z * 0.4, x, y + z * 0.35);
    g.fill();
  }
  function star(x, y, z) {
    g.beginPath();
    for (var j = 0; j < 8; j++) {
      var a = (Math.PI * j) / 4 - Math.PI / 2,
        rr = j % 2 ? z * 0.3 : z;
      g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr);
    }
    g.fill();
  }
  (function f() {
    g.clearRect(0, 0, CW, CHh);
    Q = Q.filter(function (q) {
      return q.l > 0 && q.y < CHh + 40;
    });
    for (var n = 0; n < Q.length; n++) {
      var q = Q[n];
      q.x += q.vx;
      q.y += q.vy;
      q.vy += q.g * dpr;
      q.vx *= 0.99;
      q.r += q.vr;
      q.l -= 0.014;
      g.globalAlpha = Math.min(1, q.l);
      g.fillStyle = q.c;
      g.save();
      g.translate(q.x, q.y);
      g.rotate(q.r);
      if (q.k == 'leaf') {
        g.beginPath();
        g.ellipse(0, 0, q.z, q.z * 0.45, 0, 0, 6.28);
        g.fill();
      } else if (q.k == 'heart') heart(0, 0, q.z);
      else if (q.k == 'star') star(0, 0, q.z);
      else if (q.k == 'conf') g.fillRect(-q.z / 2, -q.z / 3, q.z, q.z * 0.6);
      else {
        g.beginPath();
        g.arc(0, 0, q.z * q.l * 0.7 + 1, 0, 6.28);
        g.fill();
      }
      g.restore();
    }
    g.globalAlpha = 1;
    requestAnimationFrame(f);
  })();
  show();

  // ---- D192: the waitlist form «أبلغني عند الإطلاق» → POST /api/v1/waitlist (same origin) ----
  var form = document.getElementById('wl'),
    input = document.getElementById('wl-email'),
    button = document.getElementById('wl-send'),
    msg = document.getElementById('wl-msg');
  var state = 'idle';
  var EMAIL = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;
  function showMsg() {
    msg.className = 'wlmsg' + (state === 'ok' ? ' ok' : state === 'idle' || state === 'sending' ? '' : ' err');
    while (msg.firstChild) msg.removeChild(msg.firstChild);
    if (state === 'idle' || state === 'sending') {
      msg.appendChild(document.createTextNode(K.t('note') + ' '));
      var a = document.createElement('a');
      a.setAttribute('data-internal', '/privacy');
      a.href = en() ? '/privacy?lang=en' : '/privacy';
      a.textContent = K.t('privacy');
      msg.appendChild(a);
    } else {
      msg.textContent = K.t(state);
    }
    button.textContent = K.t(state === 'sending' ? 'sending' : 'notify');
  }
  K.onLang(showMsg);
  form.addEventListener('submit', function (ev) {
    ev.preventDefault();
    if (state === 'sending') return;
    var email = input.value.trim();
    if (email.length > 254 || !EMAIL.test(email)) {
      state = 'invalid';
      input.setAttribute('aria-invalid', 'true');
      showMsg();
      input.focus();
      return;
    }
    input.removeAttribute('aria-invalid');
    state = 'sending';
    button.disabled = true;
    showMsg();
    fetch('/api/v1/waitlist', {
      method: 'POST',
      credentials: 'omit',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ email: email, locale: K.lang() }),
    })
      .then(function (r) {
        state = r.status === 202 ? 'ok' : r.status === 400 ? 'invalid' : r.status === 429 ? 'limited' : 'failed';
      })
      .catch(function () {
        state = 'failed';
      })
      .then(function () {
        button.disabled = false;
        if (state === 'ok') form.classList.add('done');
        if (state === 'invalid') input.setAttribute('aria-invalid', 'true');
        showMsg();
      });
  });
  input.addEventListener('input', function () {
    if (state === 'invalid' || state === 'failed' || state === 'limited') {
      state = 'idle';
      input.removeAttribute('aria-invalid');
      showMsg();
    }
  });
  document.addEventListener('DOMContentLoaded', showMsg);
})();
