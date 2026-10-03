/* FAQ page search and interaction enhancements. */

// Normalizes FAQ text so searching is case-insensitive.
function normalizeFaqText(value) {
  return value.toLocaleLowerCase().trim();
}

// Filters questions and hides section headings that have no matches.
function initFaqSearch() {
  const form = document.querySelector('[data-faq-search]');
  if (!form) return;

  const input = form.querySelector('input[type="search"]');
  const groups = Array.from(document.querySelectorAll('.faq'));
  const empty = document.querySelector('[data-faq-empty]');
  const count = form.querySelector('[data-faq-count]');
  const countJoiner = count?.textContent.includes(' аз ') ? ' аз ' : count?.textContent.includes(' из ') ? ' из ' : ' of ';
  const total = groups.reduce((sum, group) => sum + group.querySelectorAll('details').length, 0);

  form.addEventListener('submit', (event) => event.preventDefault());
  input.addEventListener('input', () => {
    const query = normalizeFaqText(input.value);

    groups.forEach((group) => {
      const questions = Array.from(group.querySelectorAll('details'));
      questions.forEach((question) => {
        question.hidden = Boolean(query) && !normalizeFaqText(question.textContent).includes(query);
      });

      const heading = group.previousElementSibling;
      const hasMatch = questions.some((question) => !question.hidden);
      group.classList.toggle('faq-section-hidden', !hasMatch);
      if (heading?.matches('h2')) heading.classList.toggle('faq-section-hidden', !hasMatch);
    });

    const hasAnyMatch = groups.some((group) => !group.classList.contains('faq-section-hidden'));
    if (empty) empty.hidden = hasAnyMatch;
    const visible = groups.reduce((sum, group) => sum + group.querySelectorAll('details:not([hidden])').length, 0);
    if (count) count.textContent = `${visible}${countJoiner}${total}`;
  });
}

initFaqSearch();
