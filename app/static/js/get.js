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
}());
