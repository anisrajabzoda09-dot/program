/* Файл: рафтори аниматсияи «Насб дар 3 қадам» — саҳнаҳоро бо навбат иваз мекунад,
   бо пахши қадам ба он мегузарад, ҳангоми берун аз экран будан ё таваққуф меистад.
   Бо prefers-reduced-motion худкор намегузарад; қадамҳо бо пахш иваз мешаванд. */
(function () {
  'use strict';

  /* Як блоки аниматсияро омода мекунад. */
  function setup(root) {
    var steps = Array.prototype.slice.call(root.querySelectorAll('.ia-step'));
    var scenes = Array.prototype.slice.call(root.querySelectorAll('.ia-scene'));
    var screen = root.querySelector('.ia-screen');
    var toggle = root.querySelector('[data-ia-toggle]');
    var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var duration = parseFloat(getComputedStyle(root).getPropertyValue('--ia-dur')) * 1000 || 4400;
    var current = 1;
    var timer = null;
    var paused = false;
    var visible = false;

    /* Саҳнаи n-ро нишон медиҳад ва аниматсияҳои онро аз нав сар мекунад. */
    function show(n) {
      current = n;
      steps.forEach(function (btn, i) {
        var k = i + 1;
        btn.classList.remove('is-active');
        btn.classList.toggle('is-done', k < n);
        btn.setAttribute('aria-pressed', k === n ? 'true' : 'false');
      });
      scenes.forEach(function (scene) { scene.classList.remove('is-active'); });
      screen.removeAttribute('data-on');
      void root.offsetWidth; // reflow: аниматсияҳои CSS аз нав оғоз мешаванд
      steps[n - 1].classList.add('is-active');
      scenes[n - 1].classList.add('is-active');
      if (!reduce) screen.setAttribute('data-on', String(n));
      schedule();
    }

    /* Гузариш ба саҳнаи навбатиро ба нақша мегирад (агар бозӣ фаъол бошад). */
    function schedule() {
      clearTimeout(timer);
      if (reduce || paused || !visible) return;
      timer = setTimeout(function () { show(current % scenes.length + 1); }, duration);
    }

    steps.forEach(function (btn, i) {
      btn.addEventListener('click', function () { show(i + 1); });
    });

    if (toggle && !reduce) {
      toggle.hidden = false;
      toggle.addEventListener('click', function () {
        paused = !paused;
        root.classList.toggle('is-paused', paused);
        toggle.textContent = paused ? toggle.getAttribute('data-label-resume') : toggle.getAttribute('data-label-pause');
        if (paused) clearTimeout(timer); else schedule();
      });
    }

    // Танҳо вақте блок дар экран аст, бозӣ мекунад (батарея ва CPU-ро сарфа мекунад).
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (entries) {
        var wasVisible = visible;
        visible = entries[0].isIntersecting;
        if (visible && !wasVisible) show(current); else if (!visible) clearTimeout(timer);
      }, { threshold: 0.35 }).observe(root);
    } else {
      visible = true;
    }

    root.classList.add('is-ready');
    show(1);
  }

  function init() {
    Array.prototype.forEach.call(document.querySelectorAll('[data-install-anim]'), setup);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init, { once: true });
  } else {
    init();
  }
})();
