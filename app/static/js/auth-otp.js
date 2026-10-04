/* Файл: қадами дуюми воридшавӣ дар сайт — рамзи Authenticator пас аз парол ва воридшавӣ бо
   рамз ба почта. auth.html функсияи window.NigohAuthOtp.show(ticket)-ро даъват мекунад. */
(function () {
  'use strict';
  var strings = document.getElementById('otpStrings');
  if (!strings) return;
  var lang = strings.getAttribute('data-lang') || 'tg';
  var otpForm = document.getElementById('otpForm');
  var emailForm = document.getElementById('emailCodeForm');
  var alertSlot = document.getElementById('alertSlot');
  var alertBox = document.getElementById('alertBox');
  var ticket = null;
  var ecStage = 'email';
  // Қисмҳои саҳифа, ки ҳангоми қадами рамз пинҳон мешаванд.
  var hideWhileOtp = ['segmented', 'loginForm', 'registerForm', 'googleSignInBtn', 'appleSignInBtn', 'githubSignInBtn', 'emailCodeLink']
    .map(function (id) { return document.getElementById(id); }).filter(Boolean);
  var dividers = Array.prototype.slice.call(document.querySelectorAll('.divider, .or'));

  /* Паёмро дар ҷои хатоҳои саҳифаи воридшавӣ нишон медиҳад. */
  function say(text, isError) {
    if (!alertBox) return;
    alertBox.textContent = text;
    alertBox.classList.toggle('ok', !isError);
    alertBox.classList.toggle('err', !!isError);
    alertSlot.classList.add('show');
  }

  /* Фақат як формаи рамзро нишон медиҳад ё ҳолати аввалро бармегардонад. */
  function only(form) {
    var hide = !!form;
    // style.display истифода мешавад, чунки CSS-и тугмаҳо атрибути hidden-ро бекор мекунад.
    hideWhileOtp.concat(dividers).forEach(function (el) {
      if (el.id === 'registerForm') { if (hide) el.hidden = true; return; }
      if (el.id === 'loginForm') { el.hidden = hide; return; }
      el.style.display = hide ? 'none' : '';
    });
    if (otpForm) otpForm.hidden = form !== otpForm;
    if (emailForm) emailForm.hidden = form !== emailForm;
    if (!hide) { alertSlot && alertSlot.classList.remove('show'); }
  }

  /* POST бо JSON ва забони саҳифа. */
  async function post(url, body) {
    var res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-NIGOH-Lang': lang },
      credentials: 'same-origin',
      body: JSON.stringify(body)
    });
    var data = null;
    try { data = await res.json(); } catch (e) { data = null; }
    return { ok: res.ok, status: res.status, data: data };
  }

  /* Тугмаро ба ҳолати «интизор» мегузорад. */
  function loading(btn, on) {
    btn.disabled = on;
    btn.classList.toggle('loading', on);
  }

  /* Пас аз воридшавӣ ба саҳифаи лозимӣ мегузарад. */
  function done(data) {
    say(strings.getAttribute('data-ok'), false);
    setTimeout(function () { window.location.href = (data && data.redirect) || '/get'; }, 600);
  }

  window.NigohAuthOtp = {
    /* Пас аз пароли дуруст: формаи рамзи Authenticator. */
    show: function (t) {
      ticket = t;
      only(otpForm);
      var input = document.getElementById('otpCode');
      input.value = '';
      input.focus();
    }
  };

  document.querySelectorAll('[data-otp-back]').forEach(function (b) {
    b.addEventListener('click', function () { ticket = null; only(null); });
  });

  if (otpForm) otpForm.addEventListener('submit', async function (e) {
    e.preventDefault();
    var btn = document.getElementById('otpSubmitBtn');
    var code = document.getElementById('otpCode').value.trim();
    if (!code || !ticket) return;
    loading(btn, true);
    try {
      var r = await post('/api/auth/login/otp', { ticket: ticket, code: code });
      if (r.ok && r.data && r.data.status === 'success') return done(r.data);
      say((r.data && r.data.detail) || strings.getAttribute('data-fail'), true);
      // Чипта беэътибор шуд (мӯҳлат ё қулф) — ба формаи парол бармегардем.
      if (r.status === 401 || r.status === 429) { ticket = null; only(null); }
      loading(btn, false);
    } catch (err) {
      say(strings.getAttribute('data-net'), true);
      loading(btn, false);
    }
  });

  var link = document.querySelector('[data-email-code]');
  if (link) link.addEventListener('click', function () {
    ecStage = 'email';
    document.getElementById('ecCodeField').hidden = true;
    document.getElementById('ecResend').hidden = true;
    only(emailForm);
    var login = document.getElementById('logEmail');
    var email = document.getElementById('ecEmail');
    if (login && login.value && !email.value) email.value = login.value;
    email.focus();
  });

  /* Қадами «фиристодан» дар формаи почта. */
  async function sendCode(btn) {
    var email = document.getElementById('ecEmail').value.trim();
    if (!email) return;
    loading(btn, true);
    try {
      var r = await post('/api/auth/email-code', { email: email });
      if (r.ok) {
        say(strings.getAttribute('data-sent'), false);
        ecStage = 'code';
        document.getElementById('ecCodeField').hidden = false;
        document.getElementById('ecResend').hidden = false;
        btn.querySelector('.label').textContent = btn.getAttribute('data-verify');
        document.getElementById('ecCode').focus();
      } else {
        say((r.data && r.data.detail) || strings.getAttribute('data-fail'), true);
      }
    } catch (err) {
      say(strings.getAttribute('data-net'), true);
    }
    loading(btn, false);
  }

  if (emailForm) {
    emailForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      var btn = document.getElementById('ecSubmitBtn');
      if (ecStage === 'email') return sendCode(btn);
      var code = document.getElementById('ecCode').value.trim();
      if (code.length !== 6) return;
      loading(btn, true);
      try {
        var r = await post('/api/auth/email-code/verify', { email: document.getElementById('ecEmail').value.trim(), code: code });
        if (r.ok && r.data && r.data.status === 'otp_required') { loading(btn, false); return window.NigohAuthOtp.show(r.data.ticket); }
        if (r.ok && r.data && r.data.status === 'success') return done(r.data);
        say((r.data && r.data.detail) || strings.getAttribute('data-fail'), true);
      } catch (err) {
        say(strings.getAttribute('data-net'), true);
      }
      loading(btn, false);
    });
    document.getElementById('ecResend').addEventListener('click', function () {
      sendCode(document.getElementById('ecSubmitBtn'));
    });
  }
})();
