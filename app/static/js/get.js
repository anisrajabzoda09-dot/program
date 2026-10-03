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

  var device = detectDevice();
  document.documentElement.setAttribute('data-get-device', device);
  if (device === 'ios') {
    document.querySelectorAll('.device-note-ios').forEach(function (note) {
      note.hidden = false;
    });
  }
}());
