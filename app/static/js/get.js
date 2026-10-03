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
    if (dialog.qrOpener) dialog.qrOpener.focus();
  }

  var device = detectDevice();
  document.documentElement.setAttribute('data-get-device', device);
  if (device === 'ios') {
    document.querySelectorAll('.device-note-ios').forEach(function (note) {
      note.hidden = false;
    });
  }

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
  });
}());
