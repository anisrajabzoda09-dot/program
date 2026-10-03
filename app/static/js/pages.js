/* Progressive interactions shared by the four core marketing pages.
   Feature map:
   - home: fine-pointer card spotlights and staged rules-table rows;
   - how: scroll-linked connector progress and observed number badges;
   - features: sticky-chip scroll spy and observed checklist ticks;
   - security: one-time sequenced card highlights.
   Each initializer exits when its page hook or browser API is unavailable. */

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

// Highlight the sticky feature chip for the section nearest the viewport top.
function initFeatureScrollSpy() {
  const links = [...document.querySelectorAll('.feature-chips a[href^="#"]')];
  if (!links.length || !('IntersectionObserver' in window)) return;
  const byId = new Map(links.map((link) => [link.hash.slice(1), link]));
  const observer = new IntersectionObserver((entries) => {
    entries.filter((entry) => entry.isIntersecting).forEach((entry) => {
      links.forEach((link) => link.removeAttribute('aria-current'));
      byId.get(entry.target.id)?.setAttribute('aria-current', 'true');
    });
  }, { rootMargin: '-25% 0px -60% 0px' });
  byId.forEach((link, id) => {
    const section = document.getElementById(id);
    if (section) observer.observe(section);
  });
}

// Reveal feature checklist ticks in order when each list appears.
function initChecklistTicks() {
  const lists = document.querySelectorAll('.feature-chip-bar ~ .section .feature-list');
  if (!lists.length || !('IntersectionObserver' in window)) return;
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    });
  }, { threshold: .15 });
  lists.forEach((list) => {
    list.classList.add('is-staged');
    observer.observe(list);
  });
}

// Start the security card highlight sequence when the grid enters view.
function initSecurityCards() {
  const grid = document.querySelector('.security-grid');
  if (!grid || !('IntersectionObserver' in window)) return;
  grid.classList.add('is-staged');
  const observer = new IntersectionObserver(([entry]) => {
    if (!entry.isIntersecting) return;
    grid.classList.add('is-visible');
    observer.disconnect();
  }, { threshold: .18 });
  observer.observe(grid);
}

initCardSpotlights();
initRulesTable();
initHowTimeline();
initStepBadges();
initFeatureScrollSpy();
initChecklistTicks();
initSecurityCards();
