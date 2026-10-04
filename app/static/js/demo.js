/* Файл: интерактивии намоиши барнома дар саҳифаи /demo — гузариши экранҳо,
   банду кушоди барнома, ҷавоби дархост ва чати намоишӣ. Ҳамааш дар браузер. */
(function () {
  'use strict';
  var phone = document.querySelector('[data-demo]');
  if (!phone) return;

  /* Байни панҷ экран мегузарад ва ҳолати паймоиши поёниро нав мекунад. */
  var nav = phone.querySelector('[data-nav]');
  var views = phone.querySelectorAll('[data-view]');
  function show(name) {
    views.forEach(function (v) {
      var on = v.getAttribute('data-view') === name;
      v.classList.toggle('is-active', on);
      // Экрани чат flex-column аст; дигарҳо block.
      if (v.getAttribute('data-view') === 'chat') v.style.display = on ? 'flex' : 'none';
    });
    nav.querySelectorAll('button').forEach(function (b) {
      b.classList.toggle('is-active', b.getAttribute('data-tab') === name);
    });
  }
  nav.addEventListener('click', function (e) {
    var b = e.target.closest('[data-tab]');
    if (b) show(b.getAttribute('data-tab'));
  });

  /* Барномаро банд ё кушода мекунад ва намуди сатрро нав мекунад. */
  phone.querySelectorAll('[data-toggle]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var app = btn.closest('[data-app]');
      var blocked = btn.getAttribute('aria-pressed') !== 'true';
      btn.setAttribute('aria-pressed', blocked ? 'true' : 'false');
      app.classList.toggle('is-blocked', blocked);
      var state = app.querySelector('[data-state]');
      var bar = app.querySelector('.demo-bar span');
      if (blocked) {
        state.dataset.prev = state.textContent;
        state.textContent = phone.getAttribute('data-blocked') || 'Баста';
        state.style.color = 'var(--d-red)';
        if (bar) { bar.dataset.prev = bar.style.width; bar.style.width = '0%'; }
      } else {
        state.textContent = state.dataset.prev || state.textContent;
        state.style.color = '';
        if (bar && bar.dataset.prev) bar.style.width = bar.dataset.prev;
      }
    });
  });

  /* Дархости вақтро «иҷозат» ё «рад» мекунад ва ба ҷои корт тасдиқ нишон медиҳад. */
  var req = phone.querySelector('[data-req]');
  if (req) {
    req.querySelectorAll('[data-req-allow],[data-req-deny]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var ok = btn.hasAttribute('data-req-allow');
        req.innerHTML = '<div class="demo-done" style="color:' + (ok ? 'var(--d-green)' : 'var(--d-muted)') + '">' +
          (ok ? '✓ ' : '• ') + btn.getAttribute('data-done') + '</div>';
      });
    });
  }

  /* Паёми нав илова мекунад ва пас аз лаҳзае ҷавоби намоишии фарзандро нишон медиҳад. */
  var chat = phone.querySelector('[data-chat]');
  var input = phone.querySelector('[data-chat-input]');
  var send = phone.querySelector('[data-chat-send]');
  function bubble(cls, text, tail) {
    var el = document.createElement('div');
    el.className = 'demo-msg ' + cls;
    el.textContent = text;
    if (tail) { var s = document.createElement('small'); s.textContent = tail; el.appendChild(s); }
    chat.appendChild(el);
    chat.scrollTop = chat.scrollHeight;
    return el;
  }
  function sendMsg() {
    var text = (input.value || '').trim();
    if (!text) return;
    input.value = '';
    bubble('me', text, (phone.getAttribute('data-read') || 'Хонда шуд') + ' ✓✓');
    setTimeout(function () {
      bubble('them', phone.getAttribute('data-reply') || 'Бале, раҳмат! 🙏');
    }, 900);
  }
  if (send) send.addEventListener('click', sendMsg);
  if (input) input.addEventListener('keydown', function (e) { if (e.key === 'Enter') sendMsg(); });
})();
