(() => {
  'use strict';

  const content = document.getElementById('dashboard-content');
  const refreshButton = document.getElementById('refresh-dashboard');
  const automatic = document.getElementById('auto-refresh');
  const errorBox = document.getElementById('refresh-error');
  const syncState = document.getElementById('sync-state');
  const syncLabel = document.getElementById('sync-label');
  const modal = document.getElementById('edit-modal');
  const form = document.getElementById('edit-form');
  const saveButton = document.getElementById('edit-save');
  const filters = new Map();
  const navigation = [...document.querySelectorAll('#a-nav a')];
  let days = Number(content.querySelector('.snapshot').dataset.days);
  let requestController = null;
  let observer = null;
  let mutating = false;
  let authorizationExpired = false;

  function toast(message, success = true) {
    const notice = document.createElement('div');
    notice.className = 'toast';
    if (!success) notice.classList.add('err');
    notice.setAttribute('role', success ? 'status' : 'alert');
    notice.appendChild(document.getElementById(success ? 'tpl-ok' : 'tpl-err').content.cloneNode(true));
    const label = document.createElement('span');
    label.textContent = message;
    notice.appendChild(label);
    document.getElementById('toasts').appendChild(notice);
    requestAnimationFrame(() => notice.classList.add('show'));
    setTimeout(() => notice.remove(), success ? 3500 : 6500);
  }

  function localizeTimes() {
    content.querySelectorAll('[data-local-time]').forEach(element => {
      const raw = element.dataset.localTime;
      if (!raw) return;
      const normalized = raw.replace(' ', 'T');
      const moment = new Date(/(?:Z|[+-]\d{2}:\d{2})$/.test(normalized) ? normalized : normalized + 'Z');
      if (Number.isNaN(moment.getTime())) return;
      const options = { timeZone: 'Asia/Dushanbe', hour: '2-digit', minute: '2-digit', hour12: false };
      if (!element.hasAttribute('data-time-only')) Object.assign(options, { day: '2-digit', month: '2-digit' });
      element.textContent = new Intl.DateTimeFormat('ru-RU', options).format(moment);
      element.dateTime = moment.toISOString();
      element.title = new Intl.DateTimeFormat('ru-RU', { ...options, year: 'numeric', month: 'long', day: 'numeric' }).format(moment) + ' · Душанбе';
    });
  }

  function filterTable(tableId) {
    const table = document.getElementById(tableId);
    if (!table) return;
    const search = content.querySelector('[data-filter="' + tableId + '"]');
    const select = content.querySelector('[data-status-filter="' + tableId + '"], [data-role-filter="' + tableId + '"]');
    const query = search ? search.value.trim().toLocaleLowerCase() : '';
    const selection = select ? select.value : '';
    let visible = 0;
    const rows = [...table.rows];
    rows.forEach(row => {
      const textMatches = !query || (row.dataset.search || '').toLocaleLowerCase().includes(query);
      const statusMatches = !selection || [row.dataset.status, row.dataset.paired, row.dataset.role].includes(selection);
      row.hidden = !(textMatches && statusMatches);
      if (!row.hidden) visible += 1;
    });
    filters.set(tableId, { query: search ? search.value : '', selection });
    const counter = content.querySelector('[data-count-for="' + tableId + '"]');
    const empty = content.querySelector('[data-empty-for="' + tableId + '"]');
    if (counter) counter.textContent = visible + ' аз ' + rows.length;
    if (empty) empty.classList.toggle('show', rows.length > 0 && visible === 0);
  }

  function observeSections() {
    if (observer) observer.disconnect();
    if (!('IntersectionObserver' in window)) return;
    observer = new IntersectionObserver(entries => {
      const visible = entries.filter(entry => entry.isIntersecting);
      if (!visible.length) return;
      const section = visible[0].target.id;
      navigation.forEach(link => {
        const active = link.hash === '#' + section;
        link.classList.toggle('on', active);
        if (active) link.setAttribute('aria-current', 'location');
        else link.removeAttribute('aria-current');
      });
    }, { rootMargin: '-12% 0px -65% 0px' });
    content.querySelectorAll('.a-sec').forEach(section => observer.observe(section));
  }

  function initializeSnapshot() {
    localizeTimes();
    content.querySelectorAll('[data-filter]').forEach(input => {
      const tableId = input.dataset.filter;
      const saved = filters.get(tableId);
      if (saved) {
        input.value = saved.query;
        const select = content.querySelector('[data-status-filter="' + tableId + '"], [data-role-filter="' + tableId + '"]');
        if (select) select.value = saved.selection;
      }
      filterTable(tableId);
    });
    const snapshot = content.querySelector('.snapshot');
    const badge = document.getElementById('message-count');
    badge.textContent = snapshot.dataset.unread;
    badge.hidden = Number(snapshot.dataset.unread) === 0;
    observeSections();
  }

  async function refresh(nextDays = days, manual = false) {
    if (!manual && (document.hidden || modal.open || mutating || content.contains(document.activeElement) || authorizationExpired)) return;
    if (requestController) requestController.abort();
    const controller = new AbortController();
    requestController = controller;
    const timeout = setTimeout(() => controller.abort(), 15000);
    refreshButton.disabled = true;
    content.setAttribute('aria-busy', 'true');
    syncState.dataset.state = 'loading';
    syncLabel.textContent = 'Навсозӣ…';
    errorBox.hidden = true;
    try {
      const response = await fetch('/api/admin/dashboard?days=' + nextDays, {
        credentials: 'same-origin', cache: 'no-store', headers: { Accept: 'text/html' }, signal: controller.signal
      });
      if (response.status === 401 || response.status === 403) {
        authorizationExpired = true;
        automatic.checked = false;
        throw new Error('Муҳлати воридшавӣ тамом шуд. Барои навсозӣ аз нав ворид шавед.');
      }
      if (!response.ok || !response.headers.get('content-type')?.includes('text/html')) throw new Error('Сервер маълумоти навро барнагардонд. Боз кӯшиш кунед.');
      const documentFragment = new DOMParser().parseFromString(await response.text(), 'text/html');
      const snapshot = documentFragment.querySelector('.snapshot');
      if (!snapshot || Number(snapshot.dataset.days) !== nextDays) throw new Error('Ҷавоби сервер нопурра аст. Боз кӯшиш кунед.');
      if (controller !== requestController) return;
      const positions = [...content.querySelectorAll('.table-wrap, .chart-scroll')].map(element => [element.scrollLeft, element.scrollTop]);
      content.replaceChildren(snapshot);
      days = nextDays;
      initializeSnapshot();
      content.querySelectorAll('.table-wrap, .chart-scroll').forEach((element, index) => {
        if (positions[index]) element.scrollTo(positions[index][0], positions[index][1]);
      });
      document.querySelectorAll('[data-period]').forEach(link => {
        if (Number(link.dataset.period) === days) link.setAttribute('aria-current', 'true');
        else link.removeAttribute('aria-current');
      });
      document.getElementById('export-link').href = '/api/admin/stats/export?days=' + days;
      const currentUrl = new URL(location.href);
      currentUrl.searchParams.set('days', days);
      history.replaceState(null, '', currentUrl);
      syncState.dataset.state = 'ready';
      syncLabel.textContent = 'Маълумот нав шуд';
    } catch (error) {
      if (controller !== requestController) return;
      syncState.dataset.state = 'error';
      syncLabel.textContent = 'Навсозӣ нашуд';
      errorBox.textContent = (error.name === 'AbortError' ? 'Сервер сари вақт ҷавоб надод.' : error.message) + ' Маълумоти охирини гирифташуда намоён аст.';
      if (authorizationExpired) {
        const login = document.createElement('a');
        login.href = '/auth?admin=required';
        login.textContent = 'Ворид шудан';
        errorBox.appendChild(login);
      }
      errorBox.hidden = false;
    } finally {
      clearTimeout(timeout);
      if (controller === requestController) {
        requestController = null;
        refreshButton.disabled = false;
        content.removeAttribute('aria-busy');
      }
    }
  }

  async function post(url, payload) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(url, {
        method: 'POST', credentials: 'same-origin', signal: controller.signal,
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' }, body: JSON.stringify(payload)
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : 'Маълумот захира нашуд. Майдонҳоро санҷед.');
      return data;
    } catch (error) {
      if (error.name === 'AbortError') throw new Error('Ҷавоби сервер дер шуд. Пеш аз такрор маълумотро нав кунед.');
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  function openEditor(row) {
    form.elements.child_id.value = row.dataset.id;
    form.elements.name.value = row.dataset.name || '';
    form.elements.gender.value = row.dataset.gender === 'girl' ? 'girl' : 'boy';
    form.elements.age.value = row.dataset.age || '';
    form.elements.device_name.value = row.dataset.device || '';
    document.getElementById('edit-sub').textContent = 'Дастгоҳ #' + row.dataset.id;
    modal.showModal();
    modal.classList.add('shown');
    form.elements.name.focus();
  }

  function closeEditor() {
    if (mutating) return;
    modal.close();
    modal.classList.remove('shown');
  }

  form.addEventListener('submit', async event => {
    event.preventDefault();
    if (mutating || !form.reportValidity()) return;
    const name = form.elements.name.value.trim();
    if (!name) { toast('Номро ворид кунед', false); form.elements.name.focus(); return; }
    const age = form.elements.age.value.trim();
    const payload = {
      child_id: Number(form.elements.child_id.value), name, gender: form.elements.gender.value,
      age: age === '' ? null : Number(age), device_name: form.elements.device_name.value.trim() || null
    };
    mutating = true;
    saveButton.disabled = true;
    try {
      const result = await post('/api/admin/child/update', payload);
      mutating = false;
      closeEditor();
      toast(result.message || 'Тағйирот захира шуд');
      await refresh(days, true);
    } catch (error) {
      toast(error.message || 'Пайвастшавӣ ба сервер қатъ шуд', false);
    } finally {
      mutating = false;
      saveButton.disabled = false;
    }
  });

  content.addEventListener('click', async event => {
    const button = event.target.closest('[data-act]');
    if (!button || mutating) return;
    const row = button.closest('tr');
    if (button.dataset.act === 'edit') { openEditor(row); return; }
    if (button.dataset.act !== 'delete') return;
    if (!confirm('Профили «' + (row.dataset.name || row.dataset.id) + '» ва таърихи он нест карда шавад? Ин амалро бекор кардан ғайриимкон аст.')) return;
    mutating = true;
    button.disabled = true;
    try {
      const result = await post('/api/admin/child/delete', { child_id: Number(row.dataset.id) });
      toast(result.message || 'Профил нест карда шуд');
      await refresh(days, true);
    } catch (error) {
      toast(error.message || 'Пайвастшавӣ ба сервер қатъ шуд', false);
    } finally {
      mutating = false;
      button.disabled = false;
    }
  });

  content.addEventListener('input', event => { if (event.target.dataset.filter) filterTable(event.target.dataset.filter); });
  content.addEventListener('change', event => {
    const tableId = event.target.dataset.statusFilter || event.target.dataset.roleFilter;
    if (tableId) filterTable(tableId);
  });
  modal.querySelectorAll('[data-close]').forEach(button => button.addEventListener('click', closeEditor));
  modal.addEventListener('cancel', event => { event.preventDefault(); closeEditor(); });
  modal.addEventListener('click', event => { if (event.target === modal) closeEditor(); });
  document.querySelectorAll('[data-period]').forEach(link => link.addEventListener('click', event => {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    refresh(Number(link.dataset.period), true);
  }));
  refreshButton.addEventListener('click', () => refresh(days, true));
  document.getElementById('theme-toggle').addEventListener('click', () => {
    const theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = theme;
    try { localStorage.setItem('nigoh-theme', theme); } catch (error) {}
  });
  document.addEventListener('visibilitychange', () => { if (!document.hidden && automatic.checked) refresh(); });
  setInterval(() => { if (automatic.checked) refresh(); }, 60000);
  initializeSnapshot();
  document.documentElement.classList.add('ready');
})();
