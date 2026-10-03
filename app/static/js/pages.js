/* Progressive interactions shared by the four core marketing pages. */

// Move each home feature card's soft highlight toward the pointer.
function initCardSpotlights() {
  if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;
  document.querySelectorAll('.hero + .section .card-link').forEach((card) => {
    card.classList.add('has-spotlight');
    card.addEventListener('pointermove', (event) => {
      const bounds = card.getBoundingClientRect();
      card.style.setProperty('--spot-x', `${event.clientX - bounds.left}px`);
      card.style.setProperty('--spot-y', `${event.clientY - bounds.top}px`);
    });
  });
}

// Reveal the home rules rows in order when their table enters the viewport.
function initRulesTable() {
  const table = document.querySelector('.home-rules-card .meta-table');
  if (!table || !('IntersectionObserver' in window)) return;
  table.classList.add('is-staged');
  const observer = new IntersectionObserver(([entry]) => {
    if (!entry.isIntersecting) return;
    table.classList.add('is-visible');
    observer.disconnect();
  }, { threshold: .25 });
  observer.observe(table);
}

// Map scroll progress through the setup steps to the timeline connector.
function initHowTimeline() {
  const timeline = document.querySelector('.how-timeline');
  if (!timeline) return;
  const update = () => {
    const bounds = timeline.getBoundingClientRect();
    const viewportPoint = window.innerHeight * .7;
    const progress = Math.max(0, Math.min(1, (viewportPoint - bounds.top) / bounds.height));
    timeline.style.setProperty('--timeline-progress', progress);
  };
  update();
  addEventListener('scroll', update, { passive: true });
  addEventListener('resize', update);
}

// Mark each setup step when its numbered badge reaches the viewport.
function initStepBadges() {
  const steps = document.querySelectorAll('.how-timeline .step');
  if (!steps.length || !('IntersectionObserver' in window)) return;
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    });
  }, { threshold: .45 });
  steps.forEach((step) => {
    step.classList.add('is-staged');
    observer.observe(step);
  });
}

initCardSpotlights();
initRulesTable();
initHowTimeline();
initStepBadges();
