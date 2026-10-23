/* "Tủ của tôi": show / hide the PIN, tick the countdowns (hold time, due time, enroll code, free cancel)
   and keep the extension popup text in step with the chosen option.
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
    // v3 D4: the free cancel window. When it ends the cancel form goes away, no reload needed.
    var forms = document.querySelectorAll('form[data-cancel-from]');
    for (var k = 0; k < forms.length; k++) {
      var form = forms[k];
      var mins = Number(form.getAttribute('data-cancel-min')) || 0;
      var until = parseUtc(form.getAttribute('data-cancel-from')).getTime() + mins * 60000;
      var rest = Math.round((until - Date.now()) / 1000);
      if (isNaN(rest)) {
        continue;
      }
      if (rest <= 0 && document.querySelector('dialog[open]')) {
        continue;   // its popup is open: keep the form, the server refuses a late cancel with a message
      }
      if (rest <= 0) {
        var note = document.createElement('span');
        note.className = 'muted';
        note.textContent = 'Đã quá ' + mins + ' phút kể từ lúc đặt nên không hủy được nữa.';
        form.parentNode.replaceChild(note, form);
        continue;
      }
      var left = form.querySelector('[data-cancel-left]');
      if (left) {
        left.textContent = Math.floor(rest / 60) + ':' + two(rest % 60);
      }
    }
  }

  function money(n) {
    return (Number(n) || 0).toLocaleString('vi-VN') + ' đ';
  }

  // v3 D10: the extension popup (data-confirm, js/app.js) states the amount of the chosen option
  function syncExtend(select) {
    var form = select.form;
    var opt = select.options[select.selectedIndex];
    if (!form || !opt || !form.hasAttribute('data-extend-form')) {
      return;
    }
    var label = opt.textContent.split('·')[0].replace('+', '').trim();
    form.setAttribute('data-confirm', 'Gia hạn thêm ' + label + '? Ví bị trừ ngay ' + money(opt.getAttribute('data-price')) + '.');
  }

  document.addEventListener('change', function (e) {
    if (e.target.name === 'minutes' && e.target.form && e.target.form.hasAttribute('data-extend-form')) {
      syncExtend(e.target);
    }
  });

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
