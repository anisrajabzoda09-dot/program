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
      if (node.parentElement?.closest('button')) return;
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

// Assigns predictable fragment identifiers to every FAQ question.
function assignFaqIds(questions) {
  questions.forEach((question, index) => { question.id ||= `q-${index + 1}`; });
}

// Copies text in browsers that do not expose the asynchronous Clipboard API.
function fallbackFaqCopy(value) {
  const field = document.createElement('textarea');
  field.value = value;
  field.setAttribute('readonly', '');
  field.style.position = 'fixed';
  field.style.opacity = '0';
  document.body.append(field);
  field.select();
  document.execCommand('copy');
  field.remove();
}

// Copies a question URL and briefly confirms the successful action.
async function copyFaqLink(button, question, labels) {
  const url = `${window.location.origin}${window.location.pathname}${window.location.search}#${question.id}`;
  const accessibleLabel = button.getAttribute('aria-label');
  try {
    if (navigator.clipboard?.writeText) await navigator.clipboard.writeText(url);
    else fallbackFaqCopy(url);
  } catch {
    fallbackFaqCopy(url);
  }
  button.textContent = labels.copied;
  button.setAttribute('aria-label', labels.copied);
  window.setTimeout(() => {
    button.textContent = labels.copy;
    button.setAttribute('aria-label', accessibleLabel);
  }, 1600);
}

// Adds a localized copy-link button to each question.
function addFaqCopyButtons(questions, form) {
  const labels = { copy: form.dataset.copyLabel, copied: form.dataset.copiedLabel };
  questions.forEach((question) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'faq-copy';
    button.setAttribute('aria-live', 'polite');
    button.textContent = labels.copy;
    button.setAttribute('aria-label', form.dataset.copyA11y.replace('{}', question.querySelector('summary').textContent));
    button.addEventListener('click', () => copyFaqLink(button, question, labels));
    question.append(button);
  });
}

// Opens and scrolls to the question named by the current URL fragment.
function openFaqHash() {
  const id = decodeURIComponent(window.location.hash.slice(1));
  if (!/^q-\d+$/.test(id)) return;
  const question = document.getElementById(id);
  if (!question) return;
  question.open = true;
  question.classList.add('faq-link-target');
  question.addEventListener('animationend', () => question.classList.remove('faq-link-target'), { once: true });
  question.scrollIntoView({ block: 'center' });
}

// Replaces the URL fragment when a question is opened without moving the page.
function syncFaqHash(questions) {
  questions.forEach((question) => {
    question.addEventListener('toggle', () => {
      if (!question.open) return;
      const url = new URL(window.location.href);
      url.hash = question.id;
      history.replaceState(history.state, '', url);
    });
  });
}

// Stores the current filter in the URL so the result view can be shared.
function syncFaqQuery(value) {
  const url = new URL(window.location.href);
  if (value.trim()) url.searchParams.set('q', value.trim());
  else url.searchParams.delete('q');
  history.replaceState(history.state, '', url);
}

// Filters questions and hides section headings that have no matches.
function initFaqSearch() {
  const form = document.querySelector('[data-faq-search]');
  if (!form) return;

  const input = form.querySelector('input[type="search"]');
  const groups = Array.from(document.querySelectorAll('.faq'));
  const empty = document.querySelector('[data-faq-empty]');
  const count = form.querySelector('[data-faq-count]');
  const live = document.querySelector('[data-faq-live]');
  const countJoiner = count?.textContent.includes(' аз ') ? ' аз ' : count?.textContent.includes(' из ') ? ' из ' : ' of ';
  const total = groups.reduce((sum, group) => sum + group.querySelectorAll('details').length, 0);
  const questions = Array.from(document.querySelectorAll('.faq details'));
  const expand = form.querySelector('[data-faq-expand]');
  const collapse = form.querySelector('[data-faq-collapse]');

  assignFaqIds(questions);
  addFaqCopyButtons(questions, form);
  syncFaqHash(questions);
  if (window.location.hash) requestAnimationFrame(openFaqHash);
  window.addEventListener('hashchange', openFaqHash);

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
        const searchable = `${question.querySelector('summary').textContent} ${question.querySelector(':scope > div').textContent}`;
        question.hidden = Boolean(query) && !normalizeFaqText(searchable).includes(query);
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
    if (live) live.textContent = live.dataset.template.replace('{}', visible);
    highlightFaqMatches(input.value.trim());
    syncFaqQuery(input.value);
  });

  const initialQuery = new URL(window.location.href).searchParams.get('q');
  if (initialQuery) {
    input.value = initialQuery;
    input.dispatchEvent(new Event('input'));
  }
}

initFaqSearch();
