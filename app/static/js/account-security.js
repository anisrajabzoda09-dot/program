/* Файл: рафтори саҳифаи «Ҳимояи ҳисоб» — танзими Authenticator, тасдиқ, рамзҳои эҳтиётӣ ва хомӯш кардан. */
(function () {
  'use strict';
  var root = document.querySelector('[data-account-security]');
  if (!root) return;
  var errorBox = document.getElementById('as-error');
  var lang = root.getAttribute('data-lang') || 'tg';

  /* Хаторо дар болои саҳифа нишон медиҳад. */
  function showError(text) {
    errorBox.textContent = text || root.getAttribute('data-error');
    errorBox.hidden = false;
  }

  /* Дархости POST бо JSON; ҷавоб ё хатои сервериро бармегардонад. */
  async function post(url, body) {
    errorBox.hidden = true;
    var res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-NIGOH-Lang': lang },
      credentials: 'same-origin',
      body: body ? JSON.stringify(body) : null
    });
    var data = null;
    try { data = await res.json(); } catch (e) { data = null; }
    if (!res.ok) throw new Error(data && typeof data.detail === 'string' ? data.detail : '');
    return data;
  }

  /* Рамзҳои эҳтиётиро нишон медиҳад ва тугмаҳои нусха/боргириро омода мекунад. */
  function showCodes(codes) {
    var list = document.getElementById('as-codes-list');
    list.innerHTML = '';
    codes.forEach(function (c) { var li = document.createElement('li'); li.textContent = c; list.appendChild(li); });
    ['as-start', 'as-setup', 'as-disable-form', 'as-recovery-form'].forEach(function (id) {
      var el = document.getElementById(id); if (el) el.hidden = true;
    });
    var box = document.getElementById('as-codes');
    box.hidden = false;
    box.scrollIntoView({ block: 'center', behavior: 'smooth' });
    var text = 'NIGOH Family — recovery codes\n' + codes.join('\n') + '\n';
    document.getElementById('as-copy').onclick = function () {
      var btn = this;
      (navigator.clipboard ? navigator.clipboard.writeText(text) : Promise.reject()).then(function () {
        btn.textContent = root.getAttribute('data-copied');
      }).catch(function () {});
    };
    document.getElementById('as-download').onclick = function () {
      var a = document.createElement('a');
      a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
      a.download = 'nigoh-recovery-codes.txt';
      a.click();
      setTimeout(function () { URL.revokeObjectURL(a.href); }, 1000);
    };
  }

  var enable = document.getElementById('as-enable');
  if (enable) enable.addEventListener('click', async function () {
    enable.disabled = true;
    try {
      var data = await post('/api/account/totp/setup');
      document.getElementById('as-qr').src = data.qr;
      document.getElementById('as-secret').textContent = data.secret.replace(/(.{4})/g, '$1 ').trim();
      document.getElementById('as-start').hidden = true;
      document.getElementById('as-setup').hidden = false;
      document.getElementById('as-code').focus();
    } catch (e) { showError(e.message); enable.disabled = false; }
  });

  /* Як формаро ба endpoint мепайвандад; агар рамзҳои эҳтиётӣ оянд, онҳоро нишон медиҳад. */
  function bind(formId, inputId, url) {
    var form = document.getElementById(formId);
    if (!form) return;
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      var input = document.getElementById(inputId);
      var button = form.querySelector('button[type="submit"]');
      button.disabled = true;
      try {
        var data = await post(url, { code: input.value.trim() });
        if (data.recovery_codes) showCodes(data.recovery_codes);
        else window.location.reload();
      } catch (err) {
        showError(err.message);
        input.select();
        button.disabled = false;
      }
    });
  }
  bind('as-confirm-form', 'as-code', '/api/account/totp/confirm');
  bind('as-disable-form', 'as-disable-code', '/api/account/totp/disable');
  bind('as-recovery-form', 'as-recovery-code', '/api/account/totp/recovery');
})();
