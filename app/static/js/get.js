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
}());
