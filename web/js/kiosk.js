/* Phone page /k/{device_code}: post the 6-digit PIN, or (v7) the phone tap of the signed-in owner, to /api/kiosk/unlock
   and show the answer.
   retry_after_sec > 0 locks the PIN input with a countdown (the box refuses every PIN until then); the tap is never locked.
   v6: every try goes with intent ASK; a rented slot answers CHOOSE and the page offers "Mở tủ" (OPEN, the booking
   stays) or "Trả tủ" (CHECKOUT), then posts the same body again with that intent.
   v7: "Mở tủ của tôi" posts {method: PHONE, tap: <token of the NFC tag>}; one tap opens once, so after an UNLOCK or a
   TAP_EXPIRED the button goes away and the page asks for a new tap. */
(function () {
  'use strict';

  var form = document.getElementById('kioskForm');
  if (!form) {
    return;
  }
  var input = document.getElementById('pin');
  var button = document.getElementById('kioskSubmit');
  var result = document.getElementById('kioskResult');
  var choice = document.getElementById('kioskChoice');
  var choiceButtons = choice.querySelectorAll('[data-intent]');
  var cancel = document.getElementById('kioskChoiceCancel');
  var tapSection = document.getElementById('kioskTap');
  var tapButton = document.getElementById('tapOpen');
  var api = form.getAttribute('data-api');
  var device = form.getAttribute('data-device');
  var KEY = 'sl-kiosk-lock-' + device;
  var CHOICE_MS = 60000;      // the PIN or tap is kept in memory only this long while the choice is shown
  var lockUntil = 0;
  var timer = null;
  var busy = false;
  var chosen = null;          // the body that answered CHOOSE: {pin} or {method, tap}
  var choiceTimer = null;

  function show(text, kind) {
    result.hidden = false;
    result.className = 'kiosk__result' + (kind ? ' is-' + kind : '');
    result.textContent = text;
  }

  function setEnabled(on) {
    input.disabled = !on;
    button.disabled = !on;
  }

  function pinFree() {
    return lockUntil <= Date.now();
  }

  function setChoiceEnabled(on) {
    for (var i = 0; i < choiceButtons.length; i++) {
      choiceButtons[i].disabled = !on;
    }
    cancel.disabled = !on;
  }

  // back to the forms; the kept PIN or tap is forgotten
  function closeChoice() {
    clearTimeout(choiceTimer);
    choiceTimer = null;
    chosen = null;
    choice.hidden = true;
    form.hidden = false;
    if (tapSection) {
      tapSection.hidden = false;
    }
  }

  function openChoice(body) {
    chosen = body;
    form.hidden = true;
    if (tapSection) {
      tapSection.hidden = true;
    }
    choice.hidden = false;
    setChoiceEnabled(true);
    clearTimeout(choiceTimer);
    choiceTimer = setTimeout(function () {
      closeChoice();
      setEnabled(pinFree());
      show('Đã hết thời gian chọn. Hãy thử lại.', '');
    }, CHOICE_MS);
    choiceButtons[0].focus();
  }

  // a tap opens once: after it was used (or refused as old) the owner taps the box again for a new link
  function endTap(message) {
    if (!tapButton) {
      return;
    }
    tapButton.parentNode.removeChild(tapButton);
    tapButton = null;
    var hint = document.createElement('p');
    hint.className = 'hint';
    hint.textContent = message;
    tapSection.appendChild(hint);
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
    show(message || 'Ô mật mã đang tạm khóa.', 'wait');
    if (!timer) {
      timer = setInterval(tick, 1000);
    }
    tick();
  }

  // the PIN form back to normal, unless its lockout still runs
  function pinReady() {
    if (pinFree()) {
      setEnabled(true);
      button.textContent = 'Mở tủ';
    }
  }

  // one post; body is {pin} or {method, tap}, intent is ASK from the forms, OPEN or CHECKOUT from the choice
  function send(body, intent) {
    busy = true;
    var payload = { device_code: device, intent: intent };
    for (var k in body) {
      if (Object.prototype.hasOwnProperty.call(body, k)) {
        payload[k] = body[k];
      }
    }
    return fetch(api, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(payload)
    }).then(function (res) {
      return res.json().catch(function () {
        return { result: 'ERROR', message: 'Lỗi máy chủ, hãy thử lại.' };
      });
    }).then(function (data) {
      busy = false;
      return data;
    }, function (err) {
      busy = false;
      throw err;
    });
  }

  // the answer of any post: CHOOSE shows the two buttons, the rest ends at the forms
  function handle(data, body) {
    var wait = Number(data.retry_after_sec) || 0;
    var isTap = body.method === 'PHONE';
    if (data.result === 'CHOOSE') {
      show(data.message || 'Chọn Mở tủ hoặc Trả tủ.', '');
      openChoice(body);
      return;
    }
    closeChoice();
    // a demo box takes no token, so its button stays for the next open
    var demo = tapButton && tapButton.hasAttribute('data-demo');
    if (isTap && !demo && (data.result === 'UNLOCK' || data.reason === 'TAP_EXPIRED')) {
      endTap(data.result === 'UNLOCK'
        ? 'Lần chạm này đã được dùng. Muốn mở lại, hãy chạm điện thoại vào hộp lần nữa.'
        : 'Chạm điện thoại vào đầu đọc NFC trên hộp để có liên kết mới.');
    }
    if (data.result === 'UNLOCK') {
      pinReady();
      show(data.message || 'Tủ đang mở.', 'ok');
    } else if (wait > 0 && !isTap) {
      lock(wait, data.message);
    } else {
      pinReady();
      show(data.message || 'Không mở được tủ.', 'bad');
      if (!isTap && pinFree()) {
        input.focus();
      }
    }
  }

  function offline() {
    closeChoice();
    pinReady();
    if (tapButton) {
      tapButton.disabled = false;
      tapButton.textContent = 'Mở tủ của tôi';
    }
    show('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.', 'bad');
  }

  input.addEventListener('input', function () {
    var digits = input.value.replace(/\D/g, '').slice(0, 6);
    if (digits !== input.value) {
      input.value = digits;
    }
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    if (busy || !pinFree()) {
      return;
    }
    var pin = input.value.replace(/\D/g, '');
    if (!/^\d{6}$/.test(pin)) {
      show('Mật mã gồm đúng 6 chữ số.', 'bad');
      input.focus();
      return;
    }
    setEnabled(false);
    button.textContent = 'Đang kiểm tra…';
    send({ pin: pin }, 'ASK').then(function (data) {
      input.value = '';
      button.textContent = 'Mở tủ';
      handle(data, { pin: pin });
    }).catch(offline);
  });

  if (tapButton) {
    tapButton.addEventListener('click', function () {
      if (busy || !tapButton) {
        return;
      }
      var body = { method: 'PHONE', tap: tapButton.getAttribute('data-tap') || null };
      tapButton.disabled = true;
      tapButton.textContent = 'Đang kiểm tra…';
      send(body, 'ASK').then(function (data) {
        if (tapButton) {
          tapButton.disabled = false;
          tapButton.textContent = 'Mở tủ của tôi';
        }
        handle(data, body);
      }).catch(offline);
    });
  }

  Array.prototype.forEach.call(choiceButtons, function (b) {
    b.addEventListener('click', function () {
      if (busy || !chosen) {
        return;
      }
      var label = b.textContent;
      var body = chosen;
      setChoiceEnabled(false);
      b.textContent = 'Đang gửi…';
      send(body, b.getAttribute('data-intent')).then(function (data) {
        b.textContent = label;
        handle(data, body);
      }).catch(function () {
        b.textContent = label;
        offline();
      });
    });
  });

  cancel.addEventListener('click', function () {
    closeChoice();
    setEnabled(pinFree());
    result.hidden = true;
  });

  // a lockout seen before a reload of this page
  try {
    var saved = Number(sessionStorage.getItem(KEY)) || 0;
    if (saved > Date.now()) {
      lock(Math.ceil((saved - Date.now()) / 1000), 'Ô mật mã đang tạm khóa.');
    }
  } catch (e) { /* no storage */ }
})();
