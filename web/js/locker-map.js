/* Locker map (v5): a full-screen map with glass islands (WEB-INF/views/lockerMap.jsp).
   Data: GET data-api?area=CODE on <main id="lockerApp">, refreshed every 10 seconds.
   This file fills the area sheet (the list of areas, or one area with its banks), the slot card and the pins
   (js/area-map.js). On a phone the sheet is a bottom sheet with three heights and holds the slot card.
   Needs js/app.js first (window.SmartLocker: esc, toast, confirm).
   Actions are plain HTML forms posted to the controllers, so they also work without fetch. */
(function () {
  'use strict';

  var root = document.getElementById('lockerApp');
  if (!root) {
    return;
  }

  var REFRESH_MS = 10000;
  var HOLD_MINUTES = 15;

  var STATUS = {
    AVAILABLE: { label: 'Trống', icon: 'check' },
    RESERVED: { label: 'Đã đặt', icon: 'bookmark' },
    OCCUPIED: { label: 'Đang dùng', icon: 'box' },
    OVERDUE: { label: 'Quá hạn', icon: 'clock' },
    ALERT: { label: 'Cảnh báo', icon: 'alert' },
    MAINTENANCE: { label: 'Bảo trì', icon: 'wrench' },
    OFFLINE: { label: 'Mất kết nối', icon: 'wifiOff' }
  };
  var STATUS_ORDER = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'OVERDUE', 'ALERT', 'MAINTENANCE', 'OFFLINE'];

  var ICONS = {
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    bookmark: '<path d="M7 4h10v16l-5-3.5L7 20z"/>',
    lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    clock: '<circle cx="12" cy="12" r="8"/><path d="M12 7.5V12l3 2"/>',
    alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4.5M12 17.5v.01"/>',
    wrench: '<path d="M14.5 5.5a4 4 0 0 0-5 5L4 16l4 4 5.5-5.5a4 4 0 0 0 5-5l-2.5 2.5-2.5-.5-.5-2.5z"/>',
    wifiOff: '<path d="M3 3l18 18"/><path d="M8.5 16.5a5 5 0 0 1 7 0M5 12.5a10 10 0 0 1 4-2.3M19 12.5a10 10 0 0 0-2.6-1.8M12 19.5v.01"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    unlock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 7.6-1.7"/>',
    box: '<path d="M4 7.5l8-4 8 4v9l-8 4-8-4z"/><path d="M4 7.5l8 4 8-4M12 11.5v9"/>',
    route: '<path d="M3 11 21 3l-8 18-2-8z"/>',
    locate: '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="7.5"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22"/>',
    chevronRight: '<path d="M9 6l6 6-6 6"/>',
    refresh: '<path d="M19 12a7 7 0 1 1-2.05-4.95"/><path d="M19 4.5V8h-3.5"/>'
  };

  var cfg = {
    ctx: root.getAttribute('data-ctx') || '',
    api: root.getAttribute('data-api') || 'api/locker-map',
    role: (root.getAttribute('data-role') || 'END_USER').toUpperCase(),
    balance: Number(root.getAttribute('data-balance')) || 0,
    bookingUrl: root.getAttribute('data-booking-url') || 'BookingController',
    myLockerUrl: root.getAttribute('data-mylocker-url') || 'MyLockerController',
    topupUrl: root.getAttribute('data-topup-url') || 'TopupController',
    loginUrl: root.getAttribute('data-login-url') || 'LoginController'
  };

  var state = {
    data: null,
    area: readParam('area'),
    slotId: toInt(readParam('slot')),
    sheetMode: readParam('area') ? 'detail' : 'list',   // the list of areas, or one area
    snap: readParam('slot') ? 'full' : 'half',   // phone bottom sheet: peek | half | full
    animateBanks: false,      // the banks of an area just opened come in one after the other
    filters: {},
    query: '',
    loadedAt: 0,
    error: null,
    panelDirty: false,
    panelSig: null,           // what the slot card shows; a refresh with the same slot does not redraw it
    popupOpen: false,
    userChoseArea: false,     // the map flies to the nearest area by itself only until the visitor picks one
    placed: -1,               // pins on the map (-1 before the first answer)
    returnFocus: null
  };

  var phoneQuery = window.matchMedia('(max-width: 639px)');   // same breakpoint as css/locker-map.css
  var el = {};
  var areaMap = null;   // js/area-map.js
  // springs of js/glass-motion.js (Motion); without it every change shows at once
  var motion = window.SmartLockerMotion || (function () {
    var done = function () { return Promise.resolve(); };
    return { pop: done, leave: done, slideIn: done, stagger: done, bump: done, stopHeight: done,
             height: function (node, px) { node.style.height = px + 'px'; return done(); } };
  })();

  /* ---------- small helpers ---------- */

  function icon(name) {
    return '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' + (ICONS[name] || '') + '</svg>';
  }

  var esc = window.SmartLocker.esc;   // the one HTML escaper, from js/app.js

  function readParam(name) {
    var match = new RegExp('[?&]' + name + '=([^&#]*)').exec(window.location.search);
    return match ? decodeURIComponent(match[1].replace(/\+/g, ' ')) : null;
  }

  function toInt(value) {
    var n = parseInt(value, 10);
    return isNaN(n) ? null : n;
  }

  function isPhone() {
    return phoneQuery.matches;
  }

  function statusInfo(code) {
    return STATUS[code] || { label: code, icon: 'lock' };
  }

  function toast(message, type) {
    if (window.SmartLocker) {
      window.SmartLocker.toast(message, type);
    }
  }

  // The DB stores UTC and CONVERT(..., 121) drops the zone: "2026-10-17 07:03:00.0000000" is UTC
  function parseUtc(iso) {
    var s = String(iso).replace(' ', 'T').replace(/(\.\d{3})\d*$/, '$1');
    return new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z');
  }

  function formatTime(iso) {
    if (!iso) {
      return '';
    }
    var d = parseUtc(iso);
    if (isNaN(d.getTime())) {
      return esc(iso);
    }
    var time = d.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
    var today = new Date();
    if (d.toDateString() === today.toDateString()) {
      return time;
    }
    var two = function (n) { return (n < 10 ? '0' : '') + n; };   // 21/10, the same as <ui:dt> prints
    return two(d.getDate()) + '/' + two(d.getMonth() + 1) + ', ' + time;
  }

  // "12:34 left" under an hour, "2h 05m left" above, "late 5m" when the time has passed
  function formatCountdown(iso) {
    var diff = Math.round((parseUtc(iso).getTime() - Date.now()) / 1000);
    var late = diff < 0;
    var s = Math.abs(diff);
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var text = h > 0 ? h + ' giờ ' + (m < 10 ? '0' : '') + m + ' phút'
                     : m + ':' + (sec < 10 ? '0' : '') + sec;
    return { text: late ? 'trễ ' + text : 'còn ' + text, late: late };
  }

  function countdownHtml(iso) {
    var c = formatCountdown(iso);
    return '<span class="countdown' + (c.late ? ' is-late' : '') + '" data-countdown="' + esc(iso) + '">' + esc(c.text) + '</span>';
  }

  function deviceLabel(code) {
    var names = { ACTIVE: 'Hoạt động', MAINTENANCE: 'Bảo trì', OFFLINE: 'Mất kết nối', NONE: 'Chưa gắn thiết bị' };
    return names[code || 'ACTIVE'] || code;
  }

  function areas() {
    return (state.data && state.data.areas) || [];
  }

  // the area row of the list (counts, coordinates) for a code
  function areaInfo(code) {
    var list = areas();
    for (var i = 0; i < list.length; i++) {
      if (list[i].area_code === code) {
        return list[i];
      }
    }
    return null;
  }

  function banks() {
    return state.data && state.data.banks ? state.data.banks : [];
  }

  function findSlot(id) {
    var list = banks();
    for (var b = 0; b < list.length; b++) {
      var slots = list[b].slots || [];
      for (var s = 0; s < slots.length; s++) {
        if (slots[s].slot_id === id) {
          return { slot: slots[s], bank: list[b] };
        }
      }
    }
    return null;
  }

  function countStatuses() {
    var counts = {};
    banks().forEach(function (bank) {
      (bank.slots || []).forEach(function (slot) {
        counts[slot.status] = (counts[slot.status] || 0) + 1;
      });
    });
    return counts;
  }

  function hasFilter() {
    for (var key in state.filters) {
      if (state.filters[key]) {
        return true;
      }
    }
    return false;
  }

  function money(n) {
    return (Number(n) || 0).toLocaleString('vi-VN') + ' đ';
  }

  // the list of areas has no area in the URL, so a reload opens the list again
  function syncUrl() {
    try {
      var parts = [];
      if (state.area && state.sheetMode === 'detail') {
        parts.push('area=' + encodeURIComponent(state.area));
        if (state.slotId !== null) {
          parts.push('slot=' + state.slotId);
        }
      }
      window.history.replaceState(null, '', window.location.pathname + (parts.length ? '?' + parts.join('&') : ''));
    } catch (e) {
      // some browsers refuse replaceState (private mode, file://); the page works without it
    }
  }

  function collectRefs() {
    var refs = root.querySelectorAll('[data-ref]');
    for (var i = 0; i < refs.length; i++) {
      el[refs[i].getAttribute('data-ref')] = refs[i];
    }
  }

  /* ---------- area list ---------- */

  // how full an area is: the colour always comes with a word
  function areaTone(a) {
    if (!a.slot_count) {
      return { key: 'none', label: 'Chưa có ngăn' };
    }
    if (!a.available) {
      // every slot behind a silent (or missing) box is not "full": nothing can open it
      return a.offline >= a.slot_count ? { key: 'full', label: 'Mất kết nối' } : { key: 'full', label: 'Hết chỗ' };
    }
    return a.available / a.slot_count < 0.25 ? { key: 'low', label: 'Sắp hết' } : { key: 'ok', label: 'Còn nhiều' };
  }

  function ringHtml(a) {
    var pct = a.slot_count ? Math.round(a.available * 100 / a.slot_count) : 0;
    return '<span class="ring tone-' + areaTone(a).key + '" style="--p:' + pct + '" aria-hidden="true"><b>' + esc(a.available) + '</b></span>';
  }

  function areaMatches(a) {
    var q = state.query;
    return !q || (a.name + ' ' + a.area_code + ' ' + (a.location || '')).toLowerCase().indexOf(q) !== -1;
  }

  function renderAreas() {
    var list = areas();
    renderMap(list);
    if (!state.data) {
      return;
    }
    if (!list.length) {
      el.areas.innerHTML = '<p class="sheet-empty">Chưa có khu vực tủ nào.</p>';
      return;
    }
    var sorted = sortedAreas(list);
    var shown = sorted.filter(areaMatches);
    if (!shown.length) {
      el.areas.innerHTML = '<p class="sheet-empty">Không có khu nào khớp “' + esc(el.search.value.trim()) + '”.</p>';
      return;
    }
    el.areas.innerHTML = shown.map(function (a) {
      var dist = distanceTo(a);
      var tone = areaTone(a);
      var where = dist !== null ? formatDistance(dist) : (a.location || a.area_code);
      var tags = [];
      if (dist !== null && a === sorted[0]) {
        tags.push('<span class="gtag">Gần nhất</span>');
      }
      if (tone.key !== 'ok') {
        tags.push('<span class="gtag tone-' + tone.key + '">' + esc(tone.label) + '</span>');
      }
      if (a.alert) {
        tags.push('<span class="gtag tone-full">' + esc(a.alert) + ' cảnh báo</span>');
      }
      return '<button type="button" class="area-row lg-hover" data-area="' + esc(a.area_code) + '">' +
        ringHtml(a) +
        '<span class="area-row__body"><span class="area-row__name">' + esc(a.name) + '</span>' +
          '<span class="area-row__meta">' + esc(where) + ' · Trống ' + esc(a.available) + '/' + esc(a.slot_count) + '</span>' +
          (tags.length ? '<span class="area-row__tags">' + tags.join('') + '</span>' : '') +
        '</span>' + icon('chevronRight') +
      '</button>';
    }).join('');
  }

  function renderMap(list) {
    if (!areaMap || !state.data) {
      return;
    }
    state.placed = areaMap.update(list, state.sheetMode === 'detail' ? state.area : null);
  }

  /* ---------- one area: head, quick tiles, chips, banks ---------- */

  function renderHead() {
    var info = areaInfo(state.area);
    var area = info || (state.data && state.data.area) || null;
    el.title.textContent = area ? area.name : 'Khu vực';
    el.sub.textContent = area ? (area.location || '') : '';
    if (!info) {
      el.quick.innerHTML = '';
      return;
    }
    var go;
    if (hasCoords(info)) {
      var dist = distanceTo(info);
      var text = dist !== null ? formatDistance(dist) : 'Chỉ đường';
      go = '<a class="quick__tile quick__go lg-hover" href="' + esc(directionsUrl(info)) + '" target="_blank" rel="noopener noreferrer"' +
        ' aria-label="' + esc('Chỉ đường đến ' + info.name + (dist !== null ? ', cách ' + text : '') + ' (mở Google Maps)') + '">' +
        icon('route') + '<span>' + esc(text) + '</span></a>';
    } else {
      go = '<div class="quick__tile"><b>–</b><span>Chưa có tọa độ</span></div>';
    }
    el.quick.innerHTML = go +
      '<div class="quick__tile"><b>' + esc(info.available) + '</b><span>ngăn trống</span></div>' +
      '<div class="quick__tile"><b>' + esc(info.slot_count) + '</b><span>tổng ngăn</span></div>';
  }

  function renderChips() {
    var counts = countStatuses();
    var html = STATUS_ORDER.filter(function (code) {
      return counts[code] || state.filters[code];
    }).map(function (code) {
      return '<button type="button" class="chip lg-hover st-' + code + '" data-filter="' + code + '" aria-pressed="' + (state.filters[code] ? 'true' : 'false') + '">' +
        '<span class="chip__dot"></span>' + statusInfo(code).label +
        ' <span class="chip__count">' + (counts[code] || 0) + '</span></button>';
    }).join('');
    if (hasFilter()) {
      html += '<button type="button" class="chip chip--clear lg-hover" data-filter-clear>Bỏ lọc</button>';
    }
    el.chips.innerHTML = html;
  }

  function deviceTag(bank) {
    if (bank.device_status === 'MAINTENANCE') {
      return '<span class="device-tag device-tag--maintenance">Bảo trì</span>';
    }
    if (bank.device_status === 'OFFLINE') {
      return '<span class="device-tag device-tag--offline">Mất kết nối</span>';
    }
    if (bank.device_status === 'NONE') {
      return '<span class="device-tag device-tag--offline">Chưa gắn thiết bị</span>';
    }
    return '<span class="device-tag device-tag--live">Trực tuyến</span>';
  }

  /* cabinet (spec v3 D9): one block per bank, door height by size S 1 / M 2 / L 3 units */

  var SIZE_NAMES = { S: 'Nhỏ', M: 'Vừa', L: 'Lớn' };

  function slotHtml(slot) {
    var st = statusInfo(slot.status);
    var q = state.query;
    var size = SIZE_NAMES[slot.size] ? slot.size : 'S';
    var match = q && String(slot.slot_code).toLowerCase().indexOf(q) !== -1;
    var dim = (hasFilter() && !state.filters[slot.status]) || (q && !match);
    // a door locked for overdue is drawn in the overdue colors, whatever the box reports
    var classes = 'slot st-' + (slot.locked ? 'OVERDUE' : slot.status) + ' size-' + size +
      (slot.locked ? ' is-locked' : '') + (slot.mine ? ' is-mine' : '') + (dim ? ' is-dim' : '') +
      (match ? ' is-match' : '') + (slot.slot_id === state.slotId ? ' is-selected' : '');
    var label = slot.slot_code + ', ' + st.label + ', cỡ ' + size + (slot.locked ? ', khóa vì quá hạn' : '') +
      (slot.mine ? ', của bạn' : '');
    return '<button type="button" class="' + classes + '" data-slot="' + esc(slot.slot_id) + '" aria-label="' + esc(label) + '"' +
        ' aria-pressed="' + (slot.slot_id === state.slotId ? 'true' : 'false') + '" title="' + esc(label) + '">' +
      '<span class="slot__top"><span class="slot__code">' + esc(slot.slot_code) + '</span>' +
        '<span class="slot__size">' + size + '</span></span>' +
      '<span class="slot__icon">' + icon(slot.locked ? 'lock' : st.icon) + '</span>' +
      (slot.mine ? '<span class="slot__you">Bạn</span>' : '') +
    '</button>';
  }

  // the slots come sorted by code, door_rows of them per column, top to bottom
  function cabinetHtml(bank) {
    var per = toInt(bank.rows) || 4;
    var slots = bank.slots || [];
    var cols = [];
    for (var i = 0; i < slots.length; i += per) {
      cols.push(slots.slice(i, i + per));
    }
    return '<div class="cabinet">' + cols.map(function (col) {
      return '<div class="cabinet__col">' + col.map(slotHtml).join('') + '</div>';
    }).join('') + '</div>';
  }

  function bankFoot(bank) {
    var free = 0, used = 0, issues = 0, locked = 0;
    (bank.slots || []).forEach(function (s) {
      if (s.locked) {
        locked++;
      }
      if (s.status === 'AVAILABLE') {
        free++;
      } else if (s.status === 'OCCUPIED' || s.status === 'RESERVED' || s.status === 'OVERDUE') {
        used++;
      } else {
        issues++;
      }
    });
    return free + ' trống · ' + used + ' đang dùng' + (locked ? ' · ' + locked + ' khóa quá hạn' : '') +
      (issues ? ' · ' + issues + ' cần kiểm tra' : '');
  }

  function renderBanks() {
    var list = banks();
    if (!state.data || (!list.length && state.data.area && state.data.area.area_code !== state.area)) {
      el.banks.innerHTML = '<div class="empty">Đang tải dãy tủ…</div>';
      return;
    }
    if (!list.length) {
      el.banks.innerHTML = '<div class="empty">Khu vực này chưa có dãy tủ nào.</div>';
      return;
    }
    el.banks.innerHTML = list.map(function (bank) {
      return '<article class="bank" aria-label="' + esc(bank.name + ' ' + bank.bank_code) + '">' +
        '<header class="bank__head"><h3 class="bank__name">' + esc(bank.name) +
          '<span class="bank__code">' + esc(bank.bank_code) + (bank.device_code ? ' · ' + esc(bank.device_code) : '') + '</span>' +
          '</h3>' + deviceTag(bank) + '</header>' +
        '<div class="bank__scroll">' + cabinetHtml(bank) + '</div>' +
        '<p class="bank__foot">' + bankFoot(bank) + '</p>' +
      '</article>';
    }).join('');
    if (state.animateBanks) {
      state.animateBanks = false;
      motion.stagger(el.banks.querySelectorAll('.bank'));
    }
  }

  function renderSync() {
    var text;
    if (state.error) {
      text = 'Mất kết nối máy chủ, đang thử lại';
    } else if (!state.loadedAt) {
      text = 'Đang tải';
    } else {
      var secs = Math.max(0, Math.round((Date.now() - state.loadedAt) / 1000));
      text = secs < 3 ? 'Vừa cập nhật' : 'Cập nhật ' + secs + ' giây trước';
    }
    if (el.sync.textContent !== text) {
      el.sync.textContent = text;
    }
    el.sync.classList.toggle('is-error', !!state.error);
  }

  // the wallet pill and the account menu print the balance the API just sent
  function renderBalance() {
    var nodes = document.querySelectorAll('[data-balance-text]');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].textContent = money(cfg.balance);
      nodes[i].classList.toggle('is-debt', cfg.balance < 0);
    }
  }

  /* ---------- slot card ---------- */

  function describe(slot) {
    var mine = slot.mine;
    if (slot.locked) {
      return mine ? 'Đã quá hạn nên tủ đang khóa. Phụ phí trễ hạn được trừ vào ví; số dư phải từ 0 đ trở lên mới mở được tủ.'
                  : 'Lượt gửi trong ngăn đã quá hạn, tủ đang khóa.';
    }
    switch (slot.status) {
      case 'AVAILABLE':
        return 'Chọn gói gửi và cách mở để đặt ngăn này.';
      case 'RESERVED':
        return mine ? 'Ngăn đang giữ cho bạn. Hãy đến gửi đồ trước khi hết thời gian giữ chỗ.'
                    : 'Ngăn này đã có người đặt.';
      case 'OCCUPIED':
        return mine ? 'Đồ của bạn đang ở trong ngăn.' : 'Đang có người dùng.';
      case 'OVERDUE':
        return mine ? 'Đã hết thời gian gửi. Hãy gia hạn hoặc đến lấy đồ trước khi hết thời gian ân hạn.' : 'Đã hết thời gian gửi.';
      case 'ALERT':
        return 'Ngăn này đang có cảnh báo, nhân viên đang kiểm tra.';
      case 'MAINTENANCE':
        return 'Tạm ngưng sử dụng trong lúc kỹ thuật viên kiểm tra.';
      case 'OFFLINE':
        return 'Bộ điều khiển tủ đang mất kết nối nên không đặt được và trạng thái có thể chưa cập nhật.';
      default:
        return '';
    }
  }

  function fact(label, value) {
    return '<dt>' + label + '</dt><dd>' + value + '</dd>';
  }

  function hidden(name, value) {
    return '<input type="hidden" name="' + name + '" value="' + esc(value) + '">';
  }

  // every form carries area and slot back, so the controller can redirect to the same view
  function formStart(url, action, slot, confirmText, extra) {
    return '<form class="action-form" method="post" action="' + esc(url) + '"' +
      (confirmText ? ' data-confirm="' + esc(confirmText) + '"' : '') + (extra || '') + '>' +
      (action ? hidden('action', action) : '') +
      hidden('slotId', slot.slot_id) + hidden('area', state.area) + hidden('slot', slot.slot_id);
  }

  var METHODS = {
    PIN: { label: 'Mật mã', desc: 'Nhập 6 số trên bàn phím của hộp hoặc trên điện thoại (quét QR).' },
    CARD: { label: 'Thẻ RFID', desc: 'Quẹt thẻ RFID lên đầu đọc của hộp.' },
    FINGERPRINT: { label: 'Vân tay', desc: 'Đặt ngón tay lên cảm biến của hộp.' }
  };
  var METHOD_ORDER = ['PIN', 'CARD', 'FINGERPRINT'];

  // the numbers of the rules come from AppConfig through the API (spec v3 2.1); the defaults are only a fallback
  function rule(name, fallback) {
    var r = state.data && state.data.rules;
    return r && r[name] !== undefined && r[name] !== null ? Number(r[name]) : fallback;
  }

  function holdMinutes() {
    return rule('hold_min', (state.data && state.data.hold_min) || HOLD_MINUTES);
  }

  function cancelMinutes() {
    return rule('cancel_min', 5);
  }

  function bookingBuffer() {
    return rule('booking_buffer', 10000);
  }

  function cardDepositDue() {
    return !!(state.data && state.data.card_deposit_due);
  }

  function cardDeposit() {
    return rule('card_deposit', (state.data && state.data.card_deposit) || 30000);
  }

  function sizeInfo(code) {
    var list = (state.data && state.data.sizes) || [];
    for (var i = 0; i < list.length; i++) {
      if (list[i].code === code) {
        return list[i];
      }
    }
    return null;
  }

  // "20x20x20" -> "20×20×20 cm"
  function sizeDims(slot) {
    var z = sizeInfo(slot.size);
    var dims = (z && z.size_cm) || slot.size_cm;
    return dims ? String(dims).replace(/x/g, '×') + ' cm' : '';
  }

  // price of a plan for one size, from the server's table (plan x size factor); every open method costs the same
  function planPrice(plan, size) {
    var bySize = plan.prices && plan.prices[size];
    return bySize !== undefined ? Number(bySize) || 0 : Number(plan.price) || 0;
  }

  function fingerEnrolled(bank) {
    var list = (state.data && state.data.fp_devices) || [];
    return !!bank.device_code && list.indexOf(bank.device_code) !== -1;
  }

  function methodDesc(code, bank) {
    if (code === 'CARD' && cardDepositDue()) {
      return METHODS.CARD.desc + ' Cọc ' + money(cardDeposit()) + ' khi đăng ký thẻ lần đầu tại hộp.';
    }
    if (code === 'FINGERPRINT') {
      return METHODS.FINGERPRINT.desc + (fingerEnrolled(bank) ? ' Bạn đã đăng ký vân tay trên hộp này.'
        : ' Lần đầu cần đăng ký tại hộp bằng mã ở trang Tủ của tôi.');
    }
    return METHODS[code].desc;
  }

  // what the user is choosing: plan, open method, price taken now, and the card deposit taken later at the box
  function reserveChoice(slot) {
    var form = el.panel.querySelector('form[data-reserve]');
    var plans = (state.data && state.data.plans) || [];
    if (!form || !plans.length || !slot) {
      return null;
    }
    var pickedPlan = form.querySelector('input[name="planId"]:checked');
    var plan = plans[0];
    for (var i = 0; i < plans.length; i++) {
      if (pickedPlan && String(plans[i].plan_id) === pickedPlan.value) {
        plan = plans[i];
      }
    }
    var checked = form.querySelector('input[name="openMethod"]:checked');
    var method = checked ? checked.value : 'PIN';
    var price = planPrice(plan, slot.size);
    var deposit = method === 'CARD' && cardDepositDue() ? cardDeposit() : 0;
    var balance = Number(cfg.balance) || 0;
    // Deposit_Reserve: balance - price (- first card deposit) must stay >= BOOKING_BUFFER
    var enough = balance - price - deposit >= bookingBuffer();
    return { plan: plan, method: method, price: price, deposit: deposit, size: slot.size, balance: balance,
             after: balance - price, enough: enough };
  }

  function rulesHint() {
    var refund = rule('no_show_refund_pct', 0);
    return 'Giữ chỗ ' + holdMinutes() + ' phút · hủy trong ' + cancelMinutes() + ' phút đầu được hoàn đủ; ' +
      (refund > 0 ? 'không đến chỉ được hoàn ' + refund + '%. ' : 'không đến sẽ mất toàn bộ số tiền. ') +
      'Không đến 3 lần trong 7 ngày sẽ bị tạm khóa đặt trực tuyến.';
  }

  // the segmented controls are radios, so the form posts planId and openMethod as before
  function segOption(name, id, value, checked, inner) {
    return '<label class="seg-opt lg-hover" for="' + id + '">' +
      '<input type="radio" id="' + id + '" name="' + name + '" value="' + esc(value) + '"' + (checked ? ' checked' : '') + '>' +
      inner + '</label>';
  }

  function reserveForm(slot) {
    var plans = (state.data && state.data.plans) || [];
    if (!plans.length) {
      return '<p class="notice">Hiện chưa có gói gửi nào.</p>';
    }
    var planOpts = plans.map(function (p, i) {
      var price = planPrice(p, slot.size);
      return segOption('planId', 'pl-' + slot.slot_id + '-' + p.plan_id, p.plan_id, i === 0,
        '<span>' + esc(p.plan_name) + '</span><span class="seg-opt__sub">' + esc(price ? money(price) : 'Miễn phí') + '</span>');
    }).join('');
    var methodOpts = METHOD_ORDER.map(function (code, i) {
      return segOption('openMethod', 'om-' + slot.slot_id + '-' + code, code, i === 0, '<span>' + esc(METHODS[code].label) + '</span>');
    }).join('');
    return formStart(cfg.bookingUrl, 'reserve', slot, null, ' data-reserve') +
      '<fieldset class="seg-pick"><legend>Gói gửi</legend><div class="seg-track">' + planOpts + '</div></fieldset>' +
      '<fieldset class="seg-pick"><legend>Cách mở tủ</legend><div class="seg-track">' + methodOpts + '</div></fieldset>' +
      '<p class="hint" data-method-desc></p>' +
      '<div class="pay-now"><span>Trừ ngay</span><strong data-pay-now></strong></div>' +
      '<div class="pay-line"><span>Số dư ví</span><strong data-account-balance></strong></div>' +
      '<button type="submit" class="btn btn--block btn--pill lg-hover" data-reserve-button>Đặt ngăn ' + esc(slot.slot_code) + '</button>' +
      '<p class="notice" data-balance-warning hidden>Sau khi đặt, ví phải còn ít nhất ' +
        esc(money(bookingBuffer())) + ' để dự phòng phụ phí trễ hạn. <a href="' + esc(cfg.topupUrl) + '">Nạp tiền</a></p>' +
      '<p class="hint">' + esc(rulesHint()) + '</p>' +
    '</form>';
  }

  function updateReserveForm() {
    var found = state.slotId !== null ? findSlot(state.slotId) : null;
    var choice = found ? reserveChoice(found.slot) : null;
    if (!choice) {
      return;
    }
    el.panel.querySelector('[data-method-desc]').textContent = methodDesc(choice.method, found.bank);
    el.panel.querySelector('[data-pay-now]').textContent = choice.price ? money(choice.price) : 'Miễn phí';
    var balanceNode = el.panel.querySelector('[data-account-balance]');
    balanceNode.textContent = money(choice.balance);
    balanceNode.classList.toggle('text-danger', choice.balance < 0);
    var insufficient = !!state.loadedAt && !choice.enough;
    el.panel.querySelector('[data-reserve-button]').disabled = insufficient;
    el.panel.querySelector('[data-balance-warning]').hidden = !insufficient;
  }

  function kvHtml(rows) {
    return '<dl class="kv">' + rows.map(function (r) {
      return '<dt>' + r[0] + '</dt><dd>' + r[1] + '</dd>';
    }).join('') + '</dl>';
  }

  // the popup of spec v3 5.3: the amount taken now, the rules, the late fee of the size and the balance left
  function reserveConfirmHtml(slot, bank, choice) {
    var z = sizeInfo(choice.size) || {};
    var rows = [
      ['Ngăn', esc(slot.slot_code) + ' <span class="muted">' + esc(bank.bank_code) + '</span>'],
      ['Cỡ', esc(choice.size) + (z.size_cm ? ' <span class="muted">' + esc(z.size_cm) + ' cm</span>' : '')],
      ['Gói gửi', esc(choice.plan.plan_name)],
      ['Cách mở', esc(METHODS[choice.method].label)],
      ['Trừ ngay', '<strong class="dlg__total money">' + (choice.price ? esc(money(choice.price)) : 'Miễn phí') + '</strong>']
    ];
    if (choice.deposit) {
      rows.push(['Cọc thẻ', esc(money(choice.deposit)) + ' <span class="muted">(trừ khi đăng ký thẻ tại hộp, không trừ bây giờ)</span>']);
    }
    rows.push(['Số dư còn lại', '<span class="money">' + esc(money(choice.after)) + '</span>']);
    var refund = rule('no_show_refund_pct', 0);
    var rules = [
      ['check', 'Được hủy trong ' + cancelMinutes() + ' phút, hoàn đủ.'],
      ['clock', 'Giữ chỗ ' + holdMinutes() + ' phút từ lúc đặt.'],
      ['alert', refund > 0 ? 'Không đến chỉ được hoàn ' + refund + '% số tiền.' : 'Không đến sẽ mất toàn bộ số tiền.']
    ];
    if (z.overdue_rate) {
      rules.push(['lock', 'Quá hạn: tủ khóa, phụ phí ' + money(z.overdue_rate) + ' mỗi giờ trễ (cỡ ' + choice.size + '), trừ vào ví.']);
    }
    return kvHtml(rows) + '<ul class="rule-list">' + rules.map(function (r) {
      return '<li>' + icon(r[0]) + '<span>' + esc(r[1]) + '</span></li>';
    }).join('') + '</ul>';
  }

  function cancelUntil(slot) {
    if (!slot.reserved_at) {
      return null;
    }
    return new Date(parseUtc(slot.reserved_at).getTime() + cancelMinutes() * 60000);
  }

  function cancelForm(slot) {
    var until = cancelUntil(slot);
    if (until && until.getTime() <= Date.now()) {
      return '<p class="hint">Đã quá ' + cancelMinutes() + ' phút kể từ lúc đặt nên không hủy được nữa.</p>';
    }
    return formStart(cfg.bookingUrl, 'cancel', slot, 'Hủy lượt đặt ngăn ' + slot.slot_code + '? Số tiền đã trả được hoàn đủ vào ví.',
        until ? ' data-cancel-until="' + until.getTime() + '"' : '') +
      hidden('depositId', slot.deposit_id) +
      '<button type="submit" class="btn ghost btn--block">Hủy đặt' +
        (until ? ' · <span data-cancel-left>' + esc(leftText(until.getTime())) + '</span>' : '') + '</button>' +
    '</form>';
  }

  function leftText(endMs) {
    var s = Math.max(0, Math.round((endMs - Date.now()) / 1000));
    var m = Math.floor(s / 60);
    var sec = s % 60;
    return 'còn ' + m + ':' + (sec < 10 ? '0' : '') + sec;
  }

  function hourRate(slot) {
    var z = sizeInfo(slot.size);
    return z ? Number(z.hour_rate) || 0 : 0;
  }

  // Deposit_Extend: CEILING(minutes / 60) x the hour price of the size, taken at once
  function extendPrice(slot, minutes) {
    return Math.ceil(minutes / 60) * hourRate(slot);
  }

  var EXTEND_OPTIONS = [30, 60, 120, 240];

  function extendForm(slot) {
    var options = EXTEND_OPTIONS.map(function (m) {
      return '<option value="' + m + '"' + (m === 60 ? ' selected' : '') + '>' +
        (m < 60 ? m + ' phút' : (m / 60) + ' giờ') + ' · ' + esc(money(extendPrice(slot, m))) + '</option>';
    }).join('');
    return formStart(cfg.bookingUrl, 'extend', slot, null, ' data-extend') +
      hidden('depositId', slot.deposit_id) +
      '<h3>Gia hạn trực tuyến</h3>' +
      '<label class="field"><span>Thêm thời gian</span><select name="minutes" data-extend-minutes>' + options + '</select></label>' +
      '<p class="hint">Giá ' + esc(money(hourRate(slot))) + ' cho mỗi giờ bắt đầu thêm (cỡ ' + esc(slot.size) + '), trừ ngay vào ví. Tối đa 3 lần.</p>' +
      '<button type="submit" class="btn btn--block btn--pill lg-hover" data-extend-button>' +
        'Gia hạn · trả ' + esc(money(extendPrice(slot, 60))) + '</button>' +
    '</form>';
  }

  function extendConfirmHtml(slot, minutes) {
    var price = extendPrice(slot, minutes);
    return kvHtml([
      ['Ngăn', esc(slot.slot_code)],
      ['Thêm', esc(minutes < 60 ? minutes + ' phút' : (minutes / 60) + ' giờ')],
      ['Trừ ngay', '<strong class="dlg__total money">' + esc(money(price)) + '</strong>'],
      ['Số dư còn lại', '<span class="money">' + esc(money((Number(cfg.balance) || 0) - price)) + '</span>']
    ]);
  }

  // the owner's overdue box: locked, late hours, fee taken, debt, and the way out (top up)
  function overdueBoxHtml(slot) {
    var debt = (Number(cfg.balance) || 0) < 0 ? -Number(cfg.balance) : 0;
    return '<div class="overdue-box" role="status">' +
      '<p class="overdue-box__title">' + icon('lock') + 'Đã quá hạn, tủ đang khóa</p>' +
      '<dl class="kv">' +
        '<dt>Giờ trễ đã tính</dt><dd>' + esc(slot.overdue_hours || 0) + ' giờ</dd>' +
        '<dt>Phụ phí đã thu</dt><dd class="money">' + esc(money(slot.overdue_fee || 0)) + '</dd>' +
        '<dt>Đang nợ</dt><dd class="money' + (debt ? ' text-danger' : '') + '">' + esc(money(debt)) + '</dd>' +
      '</dl>' +
      '<p class="hint">' + (debt ? 'Nạp tiền để số dư từ 0 đ trở lên rồi mở tủ để lấy đồ. Phụ phí vẫn tính thêm mỗi giờ.'
                                  : 'Số dư đủ: mở tủ để lấy đồ ngay, phụ phí vẫn tính thêm mỗi giờ.') +
        ' Không gia hạn được khi tủ đã khóa.</p>' +
      '<a class="btn btn--block' + (debt ? '' : ' ghost') + '" href="' + esc(cfg.topupUrl) + '">Nạp tiền</a>' +
    '</div>';
  }

  // the owner's booking, whatever the slot shows (an OFFLINE box still has the booking): RESERVED until check-in, then ACTIVE
  function bookingPhase(slot) {
    if (!slot.mine || !slot.deposit_id) {
      return null;
    }
    return slot.due_at ? 'ACTIVE' : 'RESERVED';
  }

  // a visitor who is not signed in: the booking form needs an account, so the button opens the popup
  function guestBox() {
    return '<div class="guest-box"><h3>Đặt ngăn này</h3>' +
      '<p class="hint">Bạn cần có tài khoản để đặt ngăn. Đăng nhập hoặc đăng ký ngay trong cửa sổ nhỏ, ngăn bạn chọn vẫn được giữ nguyên.</p>' +
      '<button type="button" class="btn btn--block btn--pill lg-hover" data-auth-reserve="login">Đăng nhập để đặt ngăn</button>' +
      '<button type="button" class="btn ghost btn--block" data-auth-reserve="register">Tạo tài khoản mới</button></div>';
  }

  function requireLogin(tab) {
    var found = state.slotId !== null ? findSlot(state.slotId) : null;
    if (!window.SmartLockerAuth) {
      window.location.href = cfg.loginUrl;
      return;
    }
    window.SmartLockerAuth.open({
      tab: tab,
      reason: found ? 'Đăng nhập hoặc đăng ký để đặt ngăn ' + found.slot.slot_code + '. Ngăn bạn chọn vẫn được giữ nguyên.' : ''
    }).then(function (ok) {
      if (ok) {
        afterSignIn();
      }
    });
  }

  // the visitor just signed in (popup, or another tab): take the new menus and role without reloading the page,
  // keep the area and the slot, and the slot card then shows the booking form
  var SWAPPED = ['glassTabs', 'glassAccount', 'glassBalance'];

  function afterSignIn() {
    fetch(window.location.pathname + window.location.search, { credentials: 'same-origin', headers: { Accept: 'text/html' } })
      .then(function (res) { return res.text(); })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, 'text/html');
        var app = doc.getElementById('lockerApp');
        if (!app || !doc.getElementById('glassAccount')) {
          throw new Error('SHELL');   // a staff account gets the map with the sidebar: the catch reloads the page
        }
        SWAPPED.forEach(function (id) {
          var fresh = doc.getElementById(id);
          var current = document.getElementById(id);
          if (fresh && current) {
            current.innerHTML = fresh.innerHTML;
          }
        });
        cfg.role = (app.getAttribute('data-role') || 'END_USER').toUpperCase();
        cfg.balance = Number(app.getAttribute('data-balance')) || 0;
        root.setAttribute('data-role', cfg.role);
        state.panelDirty = false;
        state.panelSig = null;
        state.popupOpen = false;
        toast('Đã đăng nhập.' + (cfg.role === 'END_USER' && state.slotId !== null ? ' Chọn gói và cách mở rồi bấm Đặt ngăn.' : ''));
        load();
      })
      .catch(function () {
        window.location.reload();
      });
  }

  // There is no login page: /LoginController, /RegisterController and a page that needs a sign-in send the visitor
  // here with ?login=1 or ?register=1, and ?next= for the page to open after the sign-in (a path of this app only).
  function openAskedSignIn() {
    var tab = readParam('register') ? 'register' : (readParam('login') ? 'login' : null);
    var next = readParam('next');
    var back = next && /^\/[A-Za-z][\w\/-]*(\?[^#]*)?$/.test(next) && next.indexOf('/api/') !== 0 ? next : null;
    syncUrl();   // the address keeps only the area and the slot
    // without <dialog> the popup falls back to /LoginController, which sends the visitor back here: no loop
    if (!tab || cfg.role !== 'GUEST' || !window.SmartLockerAuth || !window.HTMLDialogElement) {
      return;
    }
    window.SmartLockerAuth.open({ tab: tab, reason: back ? 'Trang bạn vừa mở cần đăng nhập.' : '' }).then(function (ok) {
      if (!ok) {
        return;
      }
      if (back) {
        window.location.href = cfg.ctx + back;
      } else {
        afterSignIn();
      }
    });
  }

  function actionsHtml(slot, bank) {
    var role = cfg.role;
    var parts = [];
    if (role === 'GUEST') {
      if (slot.status === 'AVAILABLE') {
        parts.push(guestBox());
      }
    } else if (role === 'END_USER') {
      if (slot.status === 'AVAILABLE') {
        parts.push(reserveForm(slot));
      } else if (bookingPhase(slot) === 'RESERVED') {
        parts.push('<a class="btn btn--block btn--pill lg-hover" href="' + esc(cfg.myLockerUrl) + '">' + icon('unlock') + 'Xem cách mở ở Tủ của tôi</a>');
        parts.push(cancelForm(slot));
      } else if (slot.mine && slot.locked) {
        parts.push(overdueBoxHtml(slot));
        parts.push('<a class="btn ghost btn--block" href="' + esc(cfg.myLockerUrl) + '">Xem ở Tủ của tôi</a>');
      } else if (bookingPhase(slot) === 'ACTIVE') {
        parts.push(extendForm(slot));
      }
    }
    return parts.join('');
  }

  // prices of this slot's size, before the user pays from the account balance
  function priceHtml(slot) {
    var plans = (state.data && state.data.plans) || [];
    return plans.map(function (p) {
      var price = planPrice(p, slot.size);
      return '<span class="price-row"><span>' + esc(p.plan_name) + '</span><strong>' + (price ? esc(money(price)) : 'Miễn phí') + '</strong></span>';
    }).join('');
  }

  // a slot that is not free and not the user's only shows why; the user's own slot and a visitor's free slot show facts
  function factsHtml(slot, bank) {
    var guestPrices = cfg.role === 'GUEST' && slot.status === 'AVAILABLE';
    if (!slot.mine && !guestPrices) {
      return '';
    }
    var z = sizeInfo(slot.size);
    var facts = [];
    var prices = slot.status === 'AVAILABLE' ? priceHtml(slot) : '';
    if (prices) {
      facts.push(fact('Giá cỡ ' + esc(slot.size), '<span class="price-list">' + prices + '</span>'));
    }
    if (bank.device_status !== 'ACTIVE') {
      facts.push(fact('Thiết bị', esc(deviceLabel(bank.device_status)) + (bank.device_code ? ' <span class="muted">' + esc(bank.device_code) + '</span>' : '')));
    }
    if (z && z.overdue_rate) {
      facts.push(fact('Phụ phí trễ', esc(money(z.overdue_rate)) + ' <span class="muted">mỗi giờ</span>'));
    }
    var phase = bookingPhase(slot);
    if ((slot.status === 'RESERVED' || phase === 'RESERVED') && slot.hold_until && phase !== 'ACTIVE') {
      facts.push(fact(slot.mine ? 'Giữ cho bạn đến' : 'Giữ đến', formatTime(slot.hold_until) + countdownHtml(slot.hold_until)));
    }
    if ((slot.status === 'OCCUPIED' || slot.status === 'OVERDUE' || phase === 'ACTIVE' || slot.locked) && slot.due_at) {
      facts.push(fact('Hạn trả', formatTime(slot.due_at) + countdownHtml(slot.due_at)));
    }
    if (slot.escalated) {
      facts.push(fact('Chuyển xử lý', '<span class="text-danger">Đã chuyển cho nhân viên (quá hạn lâu)</span>'));
    }
    return facts.length ? '<dl class="facts">' + facts.join('') + '</dl>' : '';
  }

  function panelHtml(found) {
    var slot = found.slot;
    var bank = found.bank;
    var st = statusInfo(slot.status);
    var z = sizeInfo(slot.size);
    var dims = sizeDims(slot);
    var fits = slot.status === 'AVAILABLE' && z && z.items && z.items.length
      ? '<p class="size-fits"><b>Vừa với:</b> ' + esc(z.items.join(', ')) + '</p>' : '';
    return '<div class="card-head"><div>' +
        '<h2 class="card-title" id="panelTitle" tabindex="-1">Ngăn ' + esc(slot.slot_code) + '</h2>' +
        '<p class="card-sub">' + esc(bank.name) + ' · cỡ ' + esc(slot.size) + (dims ? ' · ' + esc(dims) : '') + '</p></div>' +
        '<button type="button" class="round-btn lg-hover" data-close aria-label="Bỏ chọn ngăn">' + icon('close') + '</button>' +
      '</div>' +
      '<span class="status-pill st-' + esc(slot.locked ? 'OVERDUE' : slot.status) + '">' + icon(slot.locked ? 'lock' : st.icon) +
        (slot.locked ? 'Khóa quá hạn' : esc(st.label)) + (slot.mine ? ' · của bạn' : '') + '</span>' +
      '<p class="panel-desc">' + esc(describe(slot)) + '</p>' +
      fits +
      factsHtml(slot, bank) +
      '<div class="panel-actions">' + actionsHtml(slot, bank) + '</div>';
  }

  // what the card shows about a slot; the 10 s refresh redraws the card only when this changes
  function panelSignature(found) {
    var s = found.slot;
    return [cfg.role, s.slot_id, s.status, s.locked, s.mine, s.deposit_id, s.hold_until, s.due_at, s.reserved_at,
      s.escalated, s.occupant, s.alert ? s.alert.alert_id : '', s.ticket_id, s.overdue_hours, s.overdue_fee,
      found.bank.device_status, cardDepositDue(), (state.data.fp_devices || []).join(',')].join('|');
  }

  function renderPanel(force) {
    var found = state.slotId !== null && state.data ? findSlot(state.slotId) : null;
    if (!found) {
      if (state.data && banks().length) {
        state.slotId = null;   // before the first load of the area, keep the slot asked for in the URL
      }
      el.panel.hidden = true;
      el.panel.innerHTML = '';
      state.panelDirty = false;
      state.panelSig = null;
      placePanel();
      return;
    }
    var sig = panelSignature(found);
    // keep what the user is choosing or typing when a background refresh brings the same slot
    if (!force && (state.panelDirty || sig === state.panelSig)) {
      updateReserveForm();
      return;
    }
    var appearing = el.panel.hidden;
    var otherSlot = !appearing && force;
    el.panel.innerHTML = panelHtml(found);
    el.panel.hidden = false;
    state.panelSig = sig;
    state.panelDirty = false;
    updateReserveForm();
    placePanel();
    if (appearing) {
      motion.pop(el.panel);
    } else if (otherSlot) {
      motion.slideIn(el.panel, 1);
    }
  }

  function renderDetail() {
    renderHead();
    renderChips();
    renderBanks();
  }

  function renderAll() {
    setSheetMode(state.sheetMode);
    renderAreas();
    renderNear();
    renderDetail();
    renderPanel(false);
    renderSync();
    renderBalance();
    fitSheet();
  }

  /* ---------- nearest area (spec v3 D6): the position stays in the browser, it is never sent ---------- */

  var GEO_MIN_MS = 10000;   // at most one update every 10 seconds
  var geo = { pos: null, watchId: null, lastAt: 0, message: '', wanted: false, picked: false };

  function hasCoords(a) {
    return a && typeof a.latitude === 'number' && typeof a.longitude === 'number';
  }

  // great-circle distance in metres
  function haversine(lat1, lng1, lat2, lng2) {
    var rad = Math.PI / 180;
    var dLat = (lat2 - lat1) * rad;
    var dLng = (lng2 - lng1) * rad;
    var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * 6371000 * Math.asin(Math.min(1, Math.sqrt(h)));
  }

  function distanceTo(a) {
    return geo.pos && hasCoords(a) ? haversine(geo.pos.lat, geo.pos.lng, a.latitude, a.longitude) : null;
  }

  function formatDistance(m) {
    return m < 1000 ? Math.round(m / 10) * 10 + ' m' : (m / 1000).toFixed(1).replace('.', ',') + ' km';
  }

  // nearest first; areas without coordinates keep their order at the end
  function sortedAreas(list) {
    if (!geo.pos) {
      return list;
    }
    return list.map(function (a, i) {
      return { a: a, i: i, d: distanceTo(a) };
    }).sort(function (x, y) {
      if (x.d === null || y.d === null) {
        return x.d === null && y.d === null ? x.i - y.i : (x.d === null ? 1 : -1);
      }
      return x.d - y.d;
    }).map(function (x) {
      return x.a;
    });
  }

  function directionsUrl(a) {
    return 'https://www.google.com/maps/dir/?api=1&destination=' + Number(a.latitude) + ',' + Number(a.longitude) +
      '&travelmode=walking';
  }

  function renderNear() {
    var list = areas();
    var html = '';
    if (state.placed === 0 && list.length) {
      html += '<p>Chưa có khu nào được đặt tọa độ nên bản đồ chưa có ghim. Quản trị viên nhập vĩ độ, kinh độ ở trang Khu vực.</p>';
    }
    if (list.some(hasCoords) && !geo.pos && geo.watchId === null) {
      html += '<p><button type="button" class="chip lg-hover" data-geo-start>' + icon('locate') + 'Sắp xếp theo khoảng cách</button></p>' +
        (geo.message ? '' : '<p>Cho phép trình duyệt biết vị trí để sắp các khu từ gần đến xa. Vị trí chỉ dùng trên máy của bạn, không gửi đi.</p>');
    }
    if (geo.message) {
      html += '<p class="near__msg" role="status">' + esc(geo.message) + '</p>';
    }
    el.near.innerHTML = html;
  }

  function geoStop() {
    if (geo.watchId !== null) {
      navigator.geolocation.clearWatch(geo.watchId);
      geo.watchId = null;
    }
  }

  function geoStart() {
    geo.wanted = true;
    if (!('geolocation' in navigator)) {
      geo.message = 'Trình duyệt này không hỗ trợ định vị. Danh sách khu vẫn dùng bình thường.';
    } else if (window.isSecureContext === false) {
      geo.message = 'Định vị chỉ chạy trên trang HTTPS. Danh sách khu vẫn dùng bình thường.';
    } else if (geo.watchId === null) {
      geo.message = geo.pos ? '' : 'Đang xác định vị trí…';
      geo.watchId = navigator.geolocation.watchPosition(onPosition, onGeoError,
        { enableHighAccuracy: false, maximumAge: GEO_MIN_MS, timeout: 20000 });
    }
    renderNear();
  }

  function onPosition(p) {
    var now = Date.now();
    if (geo.pos && now - geo.lastAt < GEO_MIN_MS) {
      return;
    }
    geo.lastAt = now;
    geo.pos = { lat: p.coords.latitude, lng: p.coords.longitude, acc: p.coords.accuracy };
    if (areaMap) {
      areaMap.setUser(geo.pos);
    }
    geo.message = '';
    // the first fix shows the nearest area on the map, unless the visitor already chose one or the link names one
    if (!geo.picked) {
      geo.picked = true;
      var nearest = state.data && !state.userChoseArea && !readParam('area') ? sortedAreas(areas())[0] : null;
      if (nearest && distanceTo(nearest) !== null && areaMap) {
        areaMap.focus(nearest.area_code);
      }
    }
    renderAreas();
    renderNear();
    renderHead();
  }

  function onGeoError(err) {
    if (err.code === 1) {
      geoStop();
      geo.wanted = false;
      geo.message = 'Bạn chưa cho phép định vị. Hãy bật quyền vị trí cho trang này trong trình duyệt để xem tủ gần nhất.';
    } else if (geo.pos) {
      geo.message = 'Chưa cập nhật được vị trí mới, khoảng cách tính theo vị trí trước đó.';
    } else if (err.code === 3) {
      geo.message = 'Định vị quá lâu chưa có kết quả, đang thử lại.';
    } else {
      geo.message = 'Chưa xác định được vị trí của bạn. Danh sách khu vẫn dùng bình thường.';
    }
    renderNear();
  }

  // stop the GPS while the tab is hidden, resume when it comes back
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      geoStop();
    } else if (geo.wanted) {
      geoStart();
    }
  });

  /* ---------- sheet: list / one area, and the phone bottom sheet ---------- */

  function setSheetMode(mode) {
    var changed = state.sheetMode !== mode;
    state.sheetMode = mode;
    el.listView.hidden = mode !== 'list';
    el.detailView.hidden = mode !== 'detail';
    el.sheet.setAttribute('aria-label', mode === 'list' ? 'Danh sách khu vực tủ' : 'Chi tiết khu vực');
    if (changed) {
      motion.slideIn(mode === 'list' ? el.listView : el.detailView, mode === 'list' ? -1 : 1);
    }
  }

  // on a phone the slot card lives in the bottom sheet, elsewhere it floats on its own
  function placePanel() {
    var host = isPhone() ? el.sheetSlot : root;
    if (el.panel.parentNode !== host) {
      host.appendChild(el.panel);
    }
    el.sheet.classList.toggle('has-slot', isPhone() && !el.panel.hidden);
    fitSheet();
  }

  var SNAPS = ['peek', 'half', 'full'];

  // the three heights of the phone sheet, in px: between the search pill and the tab bar, and never taller than
  // what it holds (a short list gets a short sheet, not empty glass)
  function snapHeights() {
    var top = el.search.closest('.search-pill').getBoundingClientRect().bottom + 8;
    var bottom = el.sheet.getBoundingClientRect().bottom;
    var room = Math.max(160, bottom - top);
    var content = el.sheet.querySelector('.sheet__grab').offsetHeight + bodyContentHeight() +
      el.sheet.querySelector('.sheet__foot').offsetHeight + 2;
    var full = Math.min(room, Math.max(132, content));
    return { peek: Math.min(132, full), half: Math.min(Math.round(room * 0.5), full), full: full };
  }

  // the height the body's content needs (scrollHeight never drops below the height shown, so it cannot shrink)
  function bodyContentHeight() {
    var box = el.sheetBody.getBoundingClientRect();
    var top = box.top - el.sheetBody.scrollTop;
    var bottom = 0;
    for (var i = 0; i < el.sheetBody.children.length; i++) {
      var kid = el.sheetBody.children[i];
      if (kid.getClientRects().length) {
        bottom = Math.max(bottom, kid.getBoundingClientRect().bottom - top);
      }
    }
    return Math.ceil(bottom + parseFloat(getComputedStyle(el.sheetBody).paddingBottom || 0));
  }

  // the content of the sheet changed: its height follows (only when it really differs)
  function fitSheet() {
    if (isPhone() && Math.abs(snapHeights()[state.snap] - el.sheet.getBoundingClientRect().height) > 2) {
      setSnap(state.snap);
    }
  }

  // animate: a spring of Motion to the new height (taps, drags, a chosen area); a new layout sets it at once
  function setSnap(snap, animate) {
    state.snap = snap;
    if (!isPhone()) {
      return;
    }
    var px = snapHeights()[snap];
    if (animate === false) {
      motion.stopHeight(el.sheet);
      el.sheet.style.height = px + 'px';
    } else {
      motion.height(el.sheet, px);
    }
  }

  function layoutSheet() {
    var grab = el.sheet.querySelector('[data-sheet-grab]');
    if (isPhone()) {
      grab.removeAttribute('aria-hidden');
      grab.setAttribute('tabindex', '0');
      grab.setAttribute('aria-label', 'Đổi chiều cao bảng (thấp, vừa, cao)');
      setSnap(state.snap, false);
    } else {
      grab.setAttribute('aria-hidden', 'true');
      grab.setAttribute('tabindex', '-1');
      grab.removeAttribute('aria-label');
      el.sheet.style.height = '';
    }
    placePanel();
  }

  // drag the grabber; a tap without a move steps to the next height
  function bindSheetDrag() {
    var grab = el.sheet.querySelector('[data-sheet-grab]');
    var start = null;
    grab.addEventListener('pointerdown', function (e) {
      if (!isPhone()) {
        return;
      }
      start = { y: e.clientY, h: el.sheet.getBoundingClientRect().height, moved: false };
      grab.setPointerCapture(e.pointerId);
      motion.stopHeight(el.sheet);
    });
    grab.addEventListener('pointermove', function (e) {
      if (!start) {
        return;
      }
      var dy = e.clientY - start.y;
      if (Math.abs(dy) > 4) {
        start.moved = true;
      }
      var hs = snapHeights();
      el.sheet.style.height = Math.max(hs.peek, Math.min(hs.full, start.h - dy)) + 'px';
    });
    function end() {
      if (!start) {
        return;
      }
      var hs = snapHeights();
      var h = el.sheet.getBoundingClientRect().height;
      var next;
      if (!start.moved) {
        next = SNAPS[(SNAPS.indexOf(state.snap) + 1) % SNAPS.length];
      } else {
        next = SNAPS.reduce(function (best, s) {
          return Math.abs(hs[s] - h) < Math.abs(hs[best] - h) ? s : best;
        }, 'peek');
      }
      start = null;
      setSnap(next);
    }
    grab.addEventListener('pointerup', end);
    grab.addEventListener('pointercancel', end);
    grab.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        e.preventDefault();
        var i = SNAPS.indexOf(state.snap) + (e.key === 'ArrowUp' ? 1 : -1);
        setSnap(SNAPS[Math.max(0, Math.min(SNAPS.length - 1, i))]);
      }
    });
    // a click from the keyboard (Enter, Space) has no pointer: step as a tap does
    grab.addEventListener('click', function (e) {
      if (isPhone() && e.detail === 0) {
        setSnap(SNAPS[(SNAPS.indexOf(state.snap) + 1) % SNAPS.length]);
      }
    });
  }

  // the px the islands cover, so a pin flown to stays in the free part of the map
  function mapPadding() {
    if (isPhone()) {
      return { left: 0, right: 56, top: 64, bottom: window.innerHeight - el.sheet.getBoundingClientRect().top };
    }
    return { left: el.sheet.getBoundingClientRect().right, right: 72, top: 0, bottom: 76 };
  }

  /* ---------- selection ---------- */

  function selectSlot(id) {
    state.slotId = id;
    state.returnFocus = id;
    renderBanks();
    renderPanel(true);
    syncUrl();
    if (isPhone()) {
      setSnap('full');
      el.sheetBody.scrollTop = 0;
    }
    var title = document.getElementById('panelTitle');
    if (title) {
      title.focus({ preventScroll: true });
    }
  }

  function clearSelection() {
    state.slotId = null;
    renderBanks();
    syncUrl();
    // the card leaves with a short fade before it is hidden; a slot chosen meanwhile keeps it open
    motion.leave(el.panel).then(function () {
      el.panel.style.removeProperty('transform');
      el.panel.style.removeProperty('opacity');
      if (state.slotId === null) {
        renderPanel(true);
      }
    });
    if (state.returnFocus) {
      var target = root.querySelector('[data-slot="' + state.returnFocus + '"]');
      if (target) {
        target.focus({ preventScroll: true });
      }
    }
  }

  // the list rows and the pins both end here
  function selectArea(code, byItself) {
    if (!byItself) {
      state.userChoseArea = true;
    }
    var changed = code !== state.area;
    state.area = code;
    if (changed) {
      state.slotId = null;
      state.filters = {};
      state.animateBanks = true;
      if (state.data) {
        state.data.banks = [];
      }
    }
    setSheetMode('detail');
    el.sheetBody.scrollTop = 0;
    if (isPhone() && state.snap === 'peek') {
      setSnap('half');
    }
    renderAreas();
    renderDetail();
    renderPanel(true);
    syncUrl();
    if (areaMap) {
      areaMap.focus(code);
    }
    motion.bump(el.mapCanvas.querySelector('.pin.is-active .ring'));
    if (changed) {
      load();
    }
  }

  function backToList() {
    state.slotId = null;
    setSheetMode('list');
    renderPanel(true);
    renderAreas();
    syncUrl();
    el.sheetBody.scrollTop = 0;
    var row = root.querySelector('.area-row[data-area="' + state.area + '"]');
    if (row) {
      row.focus({ preventScroll: false });
    }
  }

  /* ---------- data ---------- */

  // optional fields get defaults, so a smaller API answer still renders
  function normalize(data) {
    data.areas = data.areas || [];
    data.banks = data.banks || [];
    data.banks.forEach(function (bank) {
      bank.name = bank.name || bank.bank_code;
      bank.slots = bank.slots || [];
    });
    return data;
  }

  function onData(data) {
    if (data.guest === true && cfg.role !== 'GUEST') {
      window.location.reload();   // the session ended: draw the page for a visitor
      return;
    }
    if (data.guest === false && cfg.role === 'GUEST') {
      afterSignIn();              // signed in from another tab
      return;
    }
    state.data = normalize(data);
    if (data.balance !== undefined && data.balance !== null) {
      cfg.balance = Number(data.balance) || 0;
    }
    state.error = null;
    state.loadedAt = Date.now();
    if (data.area && data.area.area_code) {
      state.area = data.area.area_code;
    }
    if (state.popupOpen) {
      return;   // a fetch that started before the popup opened: draw it after the popup (next refresh)
    }
    renderAll();
  }

  function load() {
    var asked = state.area;
    var url = cfg.api + (cfg.api.indexOf('?') === -1 ? '?' : '&') + 'area=' + encodeURIComponent(asked || '');
    fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then(function (res) {
        var type = res.headers.get('Content-Type') || '';
        if (type.indexOf('json') === -1) {
          // SecurityFilter answered with the login page: the session has expired
          throw new Error('SESSION');
        }
        if (!res.ok) {
          throw new Error('HTTP ' + res.status);
        }
        return res.json();
      })
      .then(function (data) {
        if (asked && asked !== state.area) {
          return;   // the user picked another area while this answer was on its way
        }
        onData(data);
      })
      .catch(function (err) {
        var first = !state.error;
        state.error = err;
        renderSync();
        if (err.message === 'SESSION') {
          toast('Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.', 'error');
          window.location.reload();
        } else if (first) {
          toast('Không tải được sơ đồ tủ. Sẽ thử lại sau mỗi 10 giây.', 'error');
        }
      });
  }

  /* ---------- events ---------- */

  function onClick(e) {
    var target = e.target.closest('[data-area],[data-slot],[data-filter],[data-filter-clear],[data-close],[data-refresh],' +
      '[data-geo-start],[data-map-fit],[data-map-me],[data-map-zoom],[data-sheet-list],[data-auth-reserve]');
    if (!target) {
      return;
    }
    if (target.hasAttribute('data-area')) {
      selectArea(target.getAttribute('data-area'));
    } else if (target.hasAttribute('data-map-fit')) {
      if (areaMap) {
        areaMap.fitAll();
      }
    } else if (target.hasAttribute('data-map-me')) {
      if (areaMap && areaMap.hasUser()) {
        areaMap.focusUser();
      } else {
        geoStart();
      }
    } else if (target.hasAttribute('data-map-zoom')) {
      if (areaMap) {
        areaMap.zoom(target.getAttribute('data-map-zoom') === 'in' ? 1 : -1);
      }
    } else if (target.hasAttribute('data-sheet-list')) {
      backToList();
    } else if (target.hasAttribute('data-auth-reserve')) {
      requireLogin(target.getAttribute('data-auth-reserve'));
    } else if (target.hasAttribute('data-slot')) {
      selectSlot(toInt(target.getAttribute('data-slot')));
    } else if (target.hasAttribute('data-filter')) {
      var status = target.getAttribute('data-filter');
      state.filters[status] = !state.filters[status];
      renderChips();
      renderBanks();
    } else if (target.hasAttribute('data-filter-clear')) {
      state.filters = {};
      renderChips();
      renderBanks();
    } else if (target.hasAttribute('data-close')) {
      clearSelection();
    } else if (target.hasAttribute('data-refresh')) {
      load();
    } else if (target.hasAttribute('data-geo-start')) {
      geoStart();
    }
  }

  // the confirm popup of js/app.js; on OK the form is submitted again with data-confirmed="1"
  function askFirst(form, opts, submitter) {
    var wasDirty = state.panelDirty;
    state.panelDirty = true;   // the 10 s refresh must not replace this form while the popup is open
    state.popupOpen = true;    // nor redraw the banks (the ADMIN reconnect form lives there)
    window.SmartLocker.confirm(opts).then(function (yes) {
      state.popupOpen = false;
      if (!yes) {
        state.panelDirty = wasDirty;   // "Quay lại": the card follows the refresh again
        return;
      }
      if (!form.isConnected) {
        toast('Ngăn vừa thay đổi trạng thái. Hãy thử lại.', 'error');
        return;
      }
      form.setAttribute('data-confirmed', '1');
      if (form.requestSubmit) {
        form.requestSubmit(submitter && submitter.form === form ? submitter : undefined);
      } else {
        form.submit();
      }
    });
  }

  function onSubmit(e) {
    var form = e.target;
    if (!form.classList.contains('action-form')) {
      return;
    }
    var isReserve = form.hasAttribute('data-reserve');
    var isExtend = form.hasAttribute('data-extend');
    var needsConfirm = isReserve || isExtend || form.hasAttribute('data-confirm');
    if (needsConfirm && form.getAttribute('data-confirmed') !== '1' && window.SmartLocker && window.SmartLocker.confirm) {
      e.preventDefault();
      if (isReserve) {
        var found = findSlot(toInt(form.querySelector('[name="slotId"]').value));
        var choice = found ? reserveChoice(found.slot) : null;
        if (!found || !choice) {
          return;
        }
        askFirst(form, {
          title: 'Xác nhận đặt ngăn ' + found.slot.slot_code,
          html: reserveConfirmHtml(found.slot, found.bank, choice),
          okText: choice.price ? 'Đặt và trả ' + money(choice.price) : 'Đặt ngăn'   // the card deposit is taken later, at the box
        }, e.submitter);
      } else if (isExtend) {
        var target = findSlot(toInt(form.querySelector('[name="slotId"]').value));
        var minutes = toInt(form.querySelector('[name="minutes"]').value) || 60;
        if (!target) {
          return;
        }
        askFirst(form, {
          title: 'Gia hạn ngăn ' + target.slot.slot_code,
          html: extendConfirmHtml(target.slot, minutes),
          okText: 'Gia hạn và trả ' + money(extendPrice(target.slot, minutes))   // the amount taken now
        }, e.submitter);
      } else {
        askFirst(form, {
          title: 'Xác nhận',
          text: form.getAttribute('data-confirm'),
          okText: 'Đồng ý',
          danger: true
        }, e.submitter);
      }
      return;
    }
    // js/app.js clears data-confirmed for forms with data-confirm; the reserve and extend forms have none
    if (isReserve || isExtend) {
      form.removeAttribute('data-confirmed');
    }
    // let the browser post the form, the controller redirects back with a flash message
    var button = form.querySelector('[type="submit"]');
    if (button) {
      button.disabled = true;
      button.textContent = 'Đang gửi…';
    }
  }

  function bindEvents() {
    root.addEventListener('click', onClick);
    root.addEventListener('submit', onSubmit);
    el.panel.addEventListener('input', function () {
      state.panelDirty = true;
    });
    el.panel.addEventListener('change', function (e) {
      if (e.target.name === 'planId' || e.target.name === 'openMethod') {
        state.panelDirty = true;
        updateReserveForm();
      }
      if (e.target.hasAttribute('data-extend-minutes')) {
        var found = findSlot(state.slotId);
        var btn = el.panel.querySelector('[data-extend-button]');
        if (found && btn) {
          btn.textContent = 'Gia hạn · trả ' + money(extendPrice(found.slot, toInt(e.target.value) || 60));
        }
      }
    });
    el.search.addEventListener('input', function () {
      state.query = el.search.value.trim().toLowerCase();
      renderAreas();
      renderBanks();
    });
    el.search.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') {
        return;
      }
      e.preventDefault();
      // one area of the list, or one slot of the open area
      if (state.sheetMode === 'detail') {
        var matches = root.querySelectorAll('.slot.is-match');
        if (matches.length === 1) {
          selectSlot(toInt(matches[0].getAttribute('data-slot')));
          return;
        }
      }
      var rows = areas().filter(areaMatches);
      if (rows.length === 1) {
        selectArea(rows[0].area_code);
      }
    });
    document.addEventListener('keydown', function (e) {
      // Esc inside the confirm popup only closes the popup; a menu of the tab bar handles its own Esc
      if (e.key === 'Escape' && !e.defaultPrevented && !el.panel.hidden && !document.querySelector('dialog[open]')) {
        clearSelection();
      }
    });
    var onLayoutChange = function () {
      layoutSheet();
    };
    if (phoneQuery.addEventListener) {
      phoneQuery.addEventListener('change', onLayoutChange);
    } else {
      phoneQuery.addListener(onLayoutChange);
    }
    window.addEventListener('resize', function () {
      if (isPhone()) {
        setSnap(state.snap, false);
      }
    });
    bindSheetDrag();
    bindGlassHover();
  }

  // liquid glass hover (css/locker-map.css): the light of an island and of the button under the pointer follows it
  function bindGlassHover() {
    if (!window.matchMedia || !window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
      return;
    }
    var last = null;
    var queued = false;
    function place(node, xName, yName) {
      var r = node.getBoundingClientRect();
      node.style.setProperty(xName, Math.round(last.clientX - r.left) + 'px');
      node.style.setProperty(yName, Math.round(last.clientY - r.top) + 'px');
    }
    document.addEventListener('pointermove', function (e) {
      last = e;
      if (queued) {
        return;
      }
      queued = true;
      window.requestAnimationFrame(function () {
        queued = false;
        var target = last.target && last.target.closest ? last.target : null;
        var island = target && target.closest('.glass');
        var button = target && target.closest('.lg-hover');
        if (island) {
          place(island, '--gx', '--gy');
        }
        if (button) {
          place(button, '--mx', '--my');
        }
      });
    }, { passive: true });
  }

  function tick() {
    renderSync();
    var nodes = el.panel.querySelectorAll('[data-countdown]');
    for (var i = 0; i < nodes.length; i++) {
      var c = formatCountdown(nodes[i].getAttribute('data-countdown'));
      nodes[i].textContent = c.text;
      nodes[i].classList.toggle('is-late', c.late);
    }
    // the free cancel window (spec v3 D4): the button goes away when it ends, without a reload
    var cancels = el.panel.querySelectorAll('form[data-cancel-until]');
    for (var k = 0; k < cancels.length; k++) {
      var end = Number(cancels[k].getAttribute('data-cancel-until'));
      if (end <= Date.now() && !document.querySelector('dialog[open]')) {
        var note = document.createElement('p');
        note.className = 'hint';
        note.textContent = 'Đã quá ' + cancelMinutes() + ' phút kể từ lúc đặt nên không hủy được nữa.';
        cancels[k].parentNode.replaceChild(note, cancels[k]);
      } else {
        var left = cancels[k].querySelector('[data-cancel-left]');
        if (left) {
          left.textContent = leftText(end);
        }
      }
    }
  }

  /* ---------- start ---------- */

  document.addEventListener('sl-signed-in', afterSignIn);
  collectRefs();
  if (window.AreaMap) {
    areaMap = window.AreaMap.create(el.mapCanvas, {
      esc: esc, tone: areaTone, onSelect: selectArea, padding: mapPadding, notice: el.mapNotice
    });
  }
  bindEvents();
  layoutSheet();
  renderAll();
  // the islands come in one after the other over the map
  motion.stagger([el.search.closest('.search-pill'), el.sheet].concat(
    Array.prototype.slice.call(document.querySelectorAll('.map-right > *:not(:empty), #glassTabs, .map-legend'))), 18);
  motion.pop(document.querySelector('.flash--float'));
  // a popup (Tủ của tôi, Nạp tiền) changed the wallet or a booking: read the map again now
  document.addEventListener('sl-data-changed', load);
  load();
  openAskedSignIn();
  geoStart();   // v4: asks for the position as soon as the page opens (the browser shows its own prompt once)
  setInterval(tick, 1000);
  setInterval(function () {
    if (!document.hidden && !state.popupOpen) {
      load();
    }
  }, REFRESH_MS);
})();
