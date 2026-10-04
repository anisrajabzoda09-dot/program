/* Файл: рафтори саҳифаҳои иттилоотӣ — мундариҷаи фаъол дар матнҳои дароз,
   филтри «Чӣ нав аст», ҳисобкунаки ҳарфҳо ва санҷиши формаи тамос.
   Бе JavaScript ҳам ҳамаи саҳифаҳо пурра кор мекунанд. */
(function () {
  'use strict';

  /* Пайванди мундариҷаро, ки бахши он ҳоло дар экран аст, қайд мекунад. */
  function setupTocSpy() {
    var links = Array.prototype.slice.call(document.querySelectorAll('.prose-toc a[href^="#"]'));
    if (!links.length || !('IntersectionObserver' in window)) return;
    var byId = {};
    links.forEach(function (a) { byId[a.getAttribute('href').slice(1)] = a; });
    var visible = {};
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { visible[e.target.id] = e.isIntersecting; });
      var current = null;
      links.some(function (a) {
        var id = a.getAttribute('href').slice(1);
        if (visible[id]) { current = id; return true; }
        return false;
      });
      if (!current) return;
      links.forEach(function (a) { a.removeAttribute('aria-current'); });
      byId[current].setAttribute('aria-current', 'true');
    }, { rootMargin: '-96px 0px -55% 0px' });
    Object.keys(byId).forEach(function (id) {
      var el = document.getElementById(id);
      if (el) io.observe(el);
    });
  }

  /* Тугмаҳои «Ҳама / Муҳим» дар таърихи версияҳо. */
  function setupReleaseFilter() {
    var bar = document.querySelector('.release-filter');
    if (!bar) return;
    var buttons = Array.prototype.slice.call(bar.querySelectorAll('button[data-filter]'));
    var items = Array.prototype.slice.call(document.querySelectorAll('.timeline .release'));
    buttons.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var only = btn.getAttribute('data-filter') === 'highlight';
        buttons.forEach(function (b) { b.setAttribute('aria-pressed', b === btn ? 'true' : 'false'); });
        items.forEach(function (li) {
          li.hidden = only && !li.classList.contains('highlight');
        });
      });
    });
    bar.hidden = false;
  }

  /* Ҳисобкунаки ҳарфҳо ва санҷиши майдонҳо пеш аз фиристодани формаи тамос. */
  function setupContactForm() {
    var form = document.querySelector('.contact-form');
    if (!form) return;
    var message = form.querySelector('textarea[name="message"]');
    var counter = form.querySelector('[data-count]');
    function update() {
      if (!message || !counter) return;
      counter.textContent = message.value.length + ' / ' + message.getAttribute('maxlength');
    }
    if (message) message.addEventListener('input', update);
    update();
    form.addEventListener('submit', function (event) {
      var firstBad = null;
      Array.prototype.forEach.call(form.querySelectorAll('[required]'), function (field) {
        var ok = field.checkValidity();
        field.setAttribute('aria-invalid', ok ? 'false' : 'true');
        if (!ok && !firstBad) firstBad = field;
      });
      if (firstBad) {
        event.preventDefault();
        firstBad.focus();
        return;
      }
      var submit = form.querySelector('button[type="submit"]');
      if (submit) submit.disabled = true;
    });
  }

  function init() {
    setupTocSpy();
    setupReleaseFilter();
    setupContactForm();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init, { once: true });
  } else {
    init();
  }
})();
