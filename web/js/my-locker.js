/* "Tủ của tôi": show / hide the PIN and tick the countdowns (hold time, due time, enroll code).
   Times in data-countdown are the DB's UTC wall clock without a zone ("2026-10-17 09:03:51.123"). */
(function () {
  'use strict';

  function parseUtc(iso) {
    var s = String(iso).replace(' ', 'T').replace(/(\.\d{3})\d*$/, '$1');
    return new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z');
  }

  function two(n) {
    return (n < 10 ? '0' : '') + n;
  }

  function tick() {
    var nodes = document.querySelectorAll('[data-countdown]');
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      var end = parseUtc(node.getAttribute('data-countdown')).getTime();
      if (isNaN(end)) {
        continue;
      }
      var left = Math.round((end - Date.now()) / 1000);
      if (left <= 0) {
        node.textContent = node.getAttribute('data-late-text') || 'Đã hết giờ';
        node.classList.add('is-late');
        continue;
      }
      var h = Math.floor(left / 3600);
      var m = Math.floor((left % 3600) / 60);
      var s = left % 60;
      node.textContent = 'Còn ' + (h > 0 ? h + ' giờ ' + two(m) + ' phút' : m + ':' + two(s));
      node.classList.remove('is-late');
    }
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('[data-pin-toggle]') : null;
    if (!btn) {
      return;
    }
    var box = btn.parentNode;
    var show = btn.getAttribute('aria-pressed') !== 'true';
    box.querySelector('[data-pin-mask]').hidden = show;
    box.querySelector('[data-pin-value]').hidden = !show;
    btn.setAttribute('aria-pressed', show ? 'true' : 'false');
    btn.textContent = show ? 'Ẩn mật mã' : 'Hiện mật mã';
  });

  tick();
  setInterval(tick, 1000);
})();
