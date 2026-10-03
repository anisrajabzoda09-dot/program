/* Download page controller: progressive device-aware guidance. */
(function () {
  'use strict';

  /* Detect the broad device family used to tailor download guidance. */
  function detectDevice() {
    var agent = navigator.userAgent || '';
    if (/android/i.test(agent)) return 'android';
    if (/iPad|iPhone|iPod/.test(agent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) return 'ios';
    return 'desktop';
  }

  /* Copy a certificate fingerprint and briefly confirm success on its button. */
  function copyCertificate(button) {
    navigator.clipboard.writeText(button.dataset.copyValue).then(function () {
      var original = button.textContent;
      button.textContent = button.dataset.copySuccess;
      window.setTimeout(function () { button.textContent = original; }, 1800);
    });
  }

  /* Copy the absolute APK URL and show localized confirmation. */
  function copyDownloadLink(button) {
    var url = new URL('/download/android', window.location.origin).href;
    navigator.clipboard.writeText(url).then(function () {
      var original = button.textContent;
      button.textContent = button.dataset.copySuccess;
      window.setTimeout(function () { button.textContent = original; }, 1800);
    });
  }

  /* Show brief next-step guidance after an APK download begins. */
  function showDownloadToast() {
    var toast = document.querySelector('.download-toast');
    if (!toast) return;
    toast.hidden = false;
    window.clearTimeout(showDownloadToast.timer);
    showDownloadToast.timer = window.setTimeout(function () { toast.hidden = true; }, 6000);
  }

  /* Draw the install timeline connector according to its viewport progress. */
  function updateTimeline() {
    var timeline = document.querySelector('.install-timeline');
    if (!timeline) return;
    var rect = timeline.getBoundingClientRect();
    var travel = rect.height + window.innerHeight * .55;
    var progress = Math.max(0, Math.min(1, (window.innerHeight * .82 - rect.top) / travel));
    timeline.style.setProperty('--timeline-progress', progress.toFixed(3));
  }

  /* Open the enlarged QR dialog and place focus on its close control. */
  function openQrDialog(opener) {
    var dialog = document.querySelector('.qr-dialog');
    if (!dialog || typeof dialog.showModal !== 'function') return;
    dialog.qrOpener = opener;
    dialog.showModal();
    dialog.querySelector('.qr-dialog-close').focus();
  }

  /* Close the QR dialog and return focus to the control that opened it. */
  function closeQrDialog(dialog) {
    dialog.close();
  }

  /* Keep Tab and Shift+Tab focus inside the open QR dialog. */
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

  /* Share the current page with the system sheet or copy it as a fallback. */
  function sharePage(button) {
    var payload = { title: button.dataset.shareTitle, text: button.dataset.shareText, url: window.location.href };
    if (navigator.share) {
      navigator.share(payload).catch(function () {});
      return;
    }
    navigator.clipboard.writeText(payload.url).then(function () {
      var original = button.textContent;
      button.textContent = button.dataset.copySuccess;
      window.setTimeout(function () { button.textContent = original; }, 1800);
    });
  }

  /* Reveal the Android mobile download bar after the hero action leaves view. */
  function setupStickyDownload(device) {
    var primary = document.querySelector('.get-download-primary');
    var sticky = document.querySelector('.sticky-download');
    if (device !== 'android' || !primary || !sticky || !('IntersectionObserver' in window)) return;
    var observer = new IntersectionObserver(function (entries) {
      sticky.hidden = entries[0].isIntersecting;
    }, { threshold: 0 });
    observer.observe(primary);
  }

  /* Play the version badge highlight once when motion is allowed. */
  function shineVersionBadge() {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    var badge = document.querySelector('.version-badge');
    if (badge) window.requestAnimationFrame(function () { badge.classList.add('js-version-shine'); });
  }

  var device = detectDevice();
  document.documentElement.setAttribute('data-get-device', device);
  if (device === 'ios') {
    document.querySelectorAll('.device-note-ios').forEach(function (note) {
      note.hidden = false;
    });
  }
  setupStickyDownload(device);
  shineVersionBadge();

  document.querySelectorAll('.verify-copy').forEach(function (button) {
    button.addEventListener('click', function () { copyCertificate(button); });
  });
  document.querySelectorAll('.copy-download').forEach(function (button) {
    button.addEventListener('click', function () { copyDownloadLink(button); });
  });
  document.querySelectorAll('[data-download-action]').forEach(function (link) {
    link.addEventListener('click', showDownloadToast);
  });

  var timeline = document.querySelector('.install-timeline');
  if (timeline && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    timeline.classList.add('js-get-timeline');
    window.addEventListener('scroll', updateTimeline, { passive: true });
    window.addEventListener('resize', updateTimeline, { passive: true });
    updateTimeline();
  }

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
  document.querySelectorAll('.share-page').forEach(function (button) {
    button.addEventListener('click', function () { sharePage(button); });
  });
}());
