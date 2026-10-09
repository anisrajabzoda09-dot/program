(function () {
  'use strict';
  document.querySelectorAll('[data-install-anim]').forEach(function (guide) {
    var steps = Array.from(guide.querySelectorAll('.install-guide-step'));
    var panels = Array.from(guide.querySelectorAll('.install-guide-panel'));
    function selectStep(selectedIndex) {
      steps.forEach(function (step, index) {
        step.setAttribute('aria-pressed', index === selectedIndex ? 'true' : 'false');
        panels[index].hidden = index !== selectedIndex;
      });
    }
    steps.forEach(function (step, index) {
      step.addEventListener('click', function () { selectStep(index); });
    });
    guide.classList.add('is-ready');
    selectStep(0);
  });
})();
