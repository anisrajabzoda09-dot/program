/* Файл: идоракунии саҳифаи боргирӣ мувофиқи дастгоҳи корбар.
   Нусхабардорӣ, Web Share, QR dialog, раванди насб ва тугмаи часпандаи Android-ро идора мекунад. */
(function () {
  'use strict';

  /* Навъи умумии дастгоҳро барои мутобиқ кардани дастури боргирӣ муайян мекунад. */
  function detectDevice() {
    var agent = navigator.userAgent || '';
    if (/android/i.test(agent)) return 'android';
    if (/iPad|iPhone|iPod/.test(agent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) return 'ios';
    return 'desktop';
  }

  /* Дар браузерҳои бе Clipboard API матнро тавассути майдони муваққатӣ нусха мегирад. */
  function copyTextLegacy(value) {
    var field = document.createElement('textarea');
    field.value = value;
    field.setAttribute('readonly', '');
    field.style.position = 'fixed';
    field.style.opacity = '0';
    document.body.appendChild(field);
    field.select();
    var copied = document.execCommand('copy');
    field.remove();
    return copied;
  }

  /* Қимати саҳифаро бо Clipboard API ё роҳи эҳтиётии execCommand нусха мегирад. */
  function copyText(value) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(value).catch(function () { return copyTextLegacy(value); });
    }
    return Promise.resolve(copyTextLegacy(value));
  }

  /* Матни тугмаи нусхабардориро муваққатан бо паёми муваффақият иваз мекунад. */
  function confirmCopy(button) {
    var original = button.textContent;
    button.textContent = button.dataset.copySuccess;
    var live = document.querySelector('.get-live');
    if (live) live.textContent = button.dataset.copySuccess;
    window.setTimeout(function () { button.textContent = original; }, 1800);
  }

  /* Нақши SHA-256-и сертификатро нусха гирифта, муваффақиятро дар тугма нишон медиҳад. */
  function copyCertificate(button) {
    copyText(button.dataset.copyValue).then(function () { confirmCopy(button); });
  }

  /* URL-и пурраи APK-ро нусха гирифта, тасдиқи маҳаллиро нишон медиҳад. */
  function copyDownloadLink(button) {
    var url = new URL('/download/android', window.location.origin).href;
    copyText(url).then(function () { confirmCopy(button); });
  }

  /* Пас аз оғози боргирии APK дастури кӯтоҳи қадами навбатиро нишон медиҳад. */
  function showDownloadToast() {
    var toast = document.querySelector('.download-toast');
    if (!toast) return;
    toast.hidden = false;
    window.clearTimeout(showDownloadToast.timer);
    showDownloadToast.timer = window.setTimeout(function () { toast.hidden = true; }, 6000);
  }

  /* Хати раванди насбро мувофиқи мавқеи он дар viewport пур мекунад. */
  function updateTimeline() {
    var timeline = document.querySelector('.install-timeline');
    if (!timeline) return;
    var rect = timeline.getBoundingClientRect();
    var travel = rect.height + window.innerHeight * .55;
    var progress = Math.max(0, Math.min(1, (window.innerHeight * .82 - rect.top) / travel));
    timeline.style.setProperty('--timeline-progress', progress.toFixed(3));
  }

  /* QR dialog-и калонро кушода, focus-ро ба тугмаи бастан мегузорад. */
  function openQrDialog(opener) {
    var dialog = document.querySelector('.qr-dialog');
    if (!dialog || typeof dialog.showModal !== 'function') return;
    dialog.qrOpener = opener;
    dialog.showModal();
    dialog.querySelector('.qr-dialog-close').focus();
  }

  /* QR dialog-ро мепӯшонад; focus баъд аз рӯйдоди close баргардонда мешавад. */
  function closeQrDialog(dialog) {
    dialog.close();
  }

  /* Ҳаракати Tab ва Shift+Tab-ро дар дохили QR dialog нигоҳ медорад. */
  function trapDialogFocus(event, dialog) {
    if (event.key !== 'Tab') return;
    var controls = Array.from(dialog.querySelectorAll('button, a[href], [tabindex]:not([tabindex="-1"])'))
      .filter(function (control) { return !control.disabled && !control.hidden; });
    if (!controls.length) return;
    var first = controls[0];
    var last = controls[controls.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }

  /* Саҳифаро бо менюи системавӣ мубодила мекунад ё URL-ро нусха мегирад. */
  function sharePage(button) {
    var payload = { title: button.dataset.shareTitle, text: button.dataset.shareText, url: window.location.href };
    if (navigator.share) {
      navigator.share(payload).catch(function () {});
      return;
    }
    copyText(payload.url).then(function () { confirmCopy(button); });
  }

  /* Пас аз нопадид шудани тугмаи hero панели боргирии Android-ро нишон медиҳад. */
  function setupStickyDownload(device) {
    var primary = document.querySelector('.get-download-primary');
    var sticky = document.querySelector('.sticky-download');
    if (device !== 'android' || !primary || !sticky || !('IntersectionObserver' in window)) return;
    var observer = new IntersectionObserver(function (entries) {
      sticky.hidden = entries[0].isIntersecting;
    }, { threshold: 0 });
    observer.observe(primary);
  }

  /* Агар ҳаракат иҷозат бошад, нишони версияро як бор равшан мекунад. */
  function shineVersionBadge() {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    var badge = document.querySelector('.version-badge');
    if (badge) window.requestAnimationFrame(function () { badge.classList.add('js-version-shine'); });
  }

  /* Навъи дастгоҳро сабт карда, танҳо афзалияти дастурҳоро тағйир медиҳад. */
  var device = detectDevice();
  document.documentElement.setAttribute('data-get-device', device);
  if (device === 'ios') {
    document.querySelectorAll('.device-note-ios').forEach(function (note) {
      note.hidden = false;
    });
  }
  setupStickyDownload(device);
  shineVersionBadge();

  /* Рӯйдодҳои нусхабардорӣ ва боргириро бо паёмҳои қолаб пайваст мекунад. */
  document.querySelectorAll('.verify-copy').forEach(function (button) {
    button.addEventListener('click', function () { copyCertificate(button); });
  });
  document.querySelectorAll('.copy-download').forEach(function (button) {
    button.addEventListener('click', function () { copyDownloadLink(button); });
  });
  document.querySelectorAll('[data-download-action]').forEach(function (link) {
    link.addEventListener('click', showDownloadToast);
  });

  /* Ҳаракати раванди насбро танҳо барои корбарони бе reduced motion фаъол мекунад. */
  var timeline = document.querySelector('.install-timeline');
  if (timeline && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    timeline.classList.add('js-get-timeline');
    window.addEventListener('scroll', updateTimeline, { passive: true });
    window.addEventListener('resize', updateTimeline, { passive: true });
    updateTimeline();
  }

  /* Рӯйдодҳои pointer, замина, Escape, Tab ва бозгашти focus-и QR dialog-ро мепайвандад. */
  document.querySelectorAll('.qr-open').forEach(function (button) {
    button.addEventListener('click', function () { openQrDialog(button); });
  });
  document.querySelectorAll('.qr-dialog').forEach(function (dialog) {
    dialog.querySelector('.qr-dialog-close').addEventListener('click', function () { closeQrDialog(dialog); });
    dialog.addEventListener('click', function (event) {
      if (event.target === dialog) closeQrDialog(dialog);
    });
    dialog.addEventListener('cancel', function (event) {
      event.preventDefault();
      closeQrDialog(dialog);
    });
    dialog.addEventListener('keydown', function (event) { trapDialogFocus(event, dialog); });
    dialog.addEventListener('close', function () {
      if (dialog.qrOpener) dialog.qrOpener.focus();
    });
  });
  /* Тугмаҳои мубодиларо ба менюи системавӣ ё нусхабардории эҳтиётӣ мепайвандад. */
  document.querySelectorAll('.share-page').forEach(function (button) {
    button.addEventListener('click', function () { sharePage(button); });
  });
}());
