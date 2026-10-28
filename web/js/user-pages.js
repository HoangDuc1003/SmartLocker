/* The pages of the user: "Tủ của tôi" and "Nạp tiền", on their own or drawn inside the glass popup of the map
   (js/glass-panel.js), so every listener is on the document.
   - Tủ của tôi: show / hide the PIN, tick the countdowns (hold time, due time, enroll code, free cancel) and keep the
     extension popup text in step with the chosen option. Times in data-countdown are the DB's UTC wall clock
     without a zone ("2026-10-17 09:03:51.123").
   - Nạp tiền: the quick amounts fill the amount field and stay pressed while they match it. */
(function () {
  'use strict';

  /* ---------- Tủ của tôi ---------- */

  function parseUtc(iso) {
    var s = String(iso).replace(' ', 'T').replace(/(\.\d{3})\d*$/, '$1');
    return new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z');
  }

  function two(n) {
    return (n < 10 ? '0' : '') + n;
  }

  // on the map only the popup: the slot card of js/locker-map.js ticks its own countdowns in its own words
  function scope() {
    return document.body.classList.contains('map-page') ? document.querySelector('[data-panel-body]') : document;
  }

  function tick() {
    var root = scope();
    if (!root) {
      return;
    }
    var nodes = root.querySelectorAll('[data-countdown]');
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
    // v3 D4: full refund in the first minutes, then a part until the hold ends, then the form goes away; no reload.
    // While a confirm popup is open nothing changes: the popup keeps the amount it shows, and the server refuses
    // a lower refund than the posted expectedRefund.
    var forms = document.querySelector('dialog.dlg[open]') ? [] : root.querySelectorAll('form[data-cancel-from]');
    for (var k = 0; k < forms.length; k++) {
      var form = forms[k];
      var mins = Number(form.getAttribute('data-cancel-min')) || 0;
      var free = parseUtc(form.getAttribute('data-cancel-from')).getTime() + mins * 60000;
      var hold = parseUtc(form.getAttribute('data-hold-until')).getTime();
      var now = Date.now();
      if (isNaN(free) || isNaN(hold)) {
        continue;
      }
      if (now >= hold) {
        var note = document.createElement('span');
        note.className = 'muted';
        note.textContent = 'Đã hết thời gian giữ chỗ nên không hủy được nữa.';
        form.parentNode.replaceChild(note, form);
        continue;
      }
      if (now >= free && !form.hasAttribute('data-late')) {
        form.setAttribute('data-late', '');
        form.setAttribute('data-confirm', form.getAttribute('data-confirm-late'));
        form.querySelector('[data-expected-refund]').value = form.getAttribute('data-late-refund');
        form.querySelector('[data-cancel-label]').textContent = form.getAttribute('data-late-label');
      }
      var rest = Math.round(((form.hasAttribute('data-late') ? hold : free) - now) / 1000);
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


  /* ---------- Nạp tiền ---------- */

  function sync(form) {
    var amount = form.querySelector('#amount');
    var presets = form.querySelectorAll('.presets [data-amt]');
    for (var i = 0; i < presets.length; i++) {
      presets[i].setAttribute('aria-pressed', Number(presets[i].getAttribute('data-amt')) === Number(amount.value) ? 'true' : 'false');
    }
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.presets [data-amt]') : null;
    var form = btn && btn.closest('#topupForm');
    if (!form) {
      return;
    }
    form.querySelector('#amount').value = btn.getAttribute('data-amt');
    sync(form);
  });

  document.addEventListener('input', function (e) {
    if (e.target.id === 'amount' && e.target.closest('#topupForm')) {
      sync(e.target.closest('#topupForm'));
    }
  });

  tick();
  setInterval(tick, 1000);
})();
