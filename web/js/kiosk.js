/* Phone page /k/{device_code}: post the 6-digit PIN to /api/kiosk/unlock and show the answer.
   retry_after_sec > 0 locks the input with a countdown (the box refuses every try until then). */
(function () {
  'use strict';

  var form = document.getElementById('kioskForm');
  if (!form) {
    return;
  }
  var input = document.getElementById('pin');
  var button = document.getElementById('kioskSubmit');
  var result = document.getElementById('kioskResult');
  var api = form.getAttribute('data-api');
  var device = form.getAttribute('data-device');
  var KEY = 'sl-kiosk-lock-' + device;
  var lockUntil = 0;
  var timer = null;
  var busy = false;

  function show(text, kind) {
    result.hidden = false;
    result.className = 'kiosk__result' + (kind ? ' is-' + kind : '');
    result.textContent = text;
  }

  function setEnabled(on) {
    input.disabled = !on;
    button.disabled = !on;
  }

  function remember(until) {
    try {
      if (until) {
        sessionStorage.setItem(KEY, String(until));
      } else {
        sessionStorage.removeItem(KEY);
      }
    } catch (e) { /* private mode: the countdown still runs on this page */ }
  }

  function tick() {
    var left = Math.ceil((lockUntil - Date.now()) / 1000);
    if (left <= 0) {
      clearInterval(timer);
      timer = null;
      lockUntil = 0;
      remember(0);
      setEnabled(true);
      button.textContent = 'Mở tủ';
      show('Đã hết thời gian khóa. Bạn có thể nhập lại mật mã.', '');
      input.focus();
      return;
    }
    var m = Math.floor(left / 60);
    var s = left % 60;
    button.textContent = 'Thử lại sau ' + m + ':' + (s < 10 ? '0' : '') + s;
  }

  function lock(seconds, message) {
    lockUntil = Date.now() + seconds * 1000;
    remember(lockUntil);
    setEnabled(false);
    show(message || 'Trang này đang tạm khóa nhập.', 'wait');
    if (!timer) {
      timer = setInterval(tick, 1000);
    }
    tick();
  }

  input.addEventListener('input', function () {
    var digits = input.value.replace(/\D/g, '').slice(0, 6);
    if (digits !== input.value) {
      input.value = digits;
    }
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    if (busy || lockUntil > Date.now()) {
      return;
    }
    var pin = input.value.replace(/\D/g, '');
    if (!/^\d{6}$/.test(pin)) {
      show('Mật mã gồm đúng 6 chữ số.', 'bad');
      input.focus();
      return;
    }
    busy = true;
    setEnabled(false);
    button.textContent = 'Đang kiểm tra…';
    fetch(api, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ device_code: device, pin: pin })
    }).then(function (res) {
      return res.json().catch(function () {
        return { result: 'ERROR', message: 'Lỗi máy chủ, hãy thử lại.' };
      });
    }).then(function (data) {
      busy = false;
      input.value = '';
      var wait = Number(data.retry_after_sec) || 0;
      if (data.result === 'UNLOCK') {
        setEnabled(true);
        button.textContent = 'Mở tủ';
        show(data.message || 'Tủ đang mở.', 'ok');
      } else if (wait > 0) {
        lock(wait, data.message);
      } else {
        setEnabled(true);
        button.textContent = 'Mở tủ';
        show(data.message || 'Không mở được tủ.', 'bad');
        input.focus();
      }
    }).catch(function () {
      busy = false;
      setEnabled(true);
      button.textContent = 'Mở tủ';
      show('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.', 'bad');
    });
  });

  // a lockout seen before a reload of this page
  try {
    var saved = Number(sessionStorage.getItem(KEY)) || 0;
    if (saved > Date.now()) {
      lock(Math.ceil((saved - Date.now()) / 1000), 'Trang này đang tạm khóa nhập.');
    }
  } catch (e) { /* no storage */ }
})();
