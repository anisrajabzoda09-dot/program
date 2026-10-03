/* FAQ page search and interaction enhancements. */

// Normalizes FAQ text so searching is case-insensitive.
function normalizeFaqText(value) {
  return value.toLocaleLowerCase().trim();
}

// Removes search highlights and joins their text back into the original content.
function clearFaqMarks() {
  document.querySelectorAll('.faq mark[data-faq-mark]').forEach((mark) => {
    const parent = mark.parentNode;
    mark.replaceWith(document.createTextNode(mark.textContent));
    parent.normalize();
  });
}

// Highlights each visible occurrence of the current search phrase.
function highlightFaqMatches(query) {
  clearFaqMarks();
  if (!query) return;

  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const expression = new RegExp(escaped, 'giu');
  document.querySelectorAll('.faq details:not([hidden])').forEach((question) => {
    const walker = document.createTreeWalker(question, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);

    nodes.forEach((node) => {
      expression.lastIndex = 0;
      if (!expression.test(node.data)) return;

      const fragment = document.createDocumentFragment();
      let cursor = 0;
      node.data.replace(expression, (match, offset) => {
        fragment.append(node.data.slice(cursor, offset));
        const mark = document.createElement('mark');
        mark.dataset.faqMark = '';
        mark.textContent = match;
        fragment.append(mark);
        cursor = offset + match.length;
        return match;
      });
      fragment.append(node.data.slice(cursor));
      node.replaceWith(fragment);
    });
  });
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
  const questions = Array.from(document.querySelectorAll('.faq details'));
  const expand = form.querySelector('[data-faq-expand]');
  const collapse = form.querySelector('[data-faq-collapse]');

  form.addEventListener('submit', (event) => event.preventDefault());
  expand?.addEventListener('click', () => questions.filter((question) => !question.hidden).forEach((question) => { question.open = true; }));
  collapse?.addEventListener('click', () => questions.forEach((question) => { question.open = false; }));
  document.addEventListener('keydown', (event) => {
    const isTyping = event.target.matches('input, textarea, select, [contenteditable="true"]');
    if (event.key === '/' && !isTyping && !event.metaKey && !event.ctrlKey && !event.altKey) {
      event.preventDefault();
      input.focus();
    }
    if (event.key === 'Escape' && input.value) {
      input.value = '';
      input.dispatchEvent(new Event('input'));
      input.focus();
    }
  });
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
    highlightFaqMatches(input.value.trim());
  });
}

initFaqSearch();
