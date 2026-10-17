/* Locker map: area menu, locker banks and the slot detail panel.
   Data: GET data-api?area=CODE on <main id="lockerApp">, refreshed every 10 seconds.
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
  var STAFF_ROLES = ['ADMIN', 'OPERATOR'];
  var ALERT_READERS = ['ADMIN', 'OPERATOR', 'TECHNICIAN', 'AUDITOR'];

  var STATUS = {
    AVAILABLE: { label: 'Trống', icon: 'check' },
    RESERVED: { label: 'Đã đặt', icon: 'bookmark' },
    OCCUPIED: { label: 'Đang dùng', icon: 'lock' },
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
    search: '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>',
    refresh: '<path d="M19 12a7 7 0 1 1-2.05-4.95"/><path d="M19 4.5V8h-3.5"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    pin: '<path d="M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0 1 13 0c0 4.8-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
    unlock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 7.6-1.7"/>'
  };

  var cfg = {
    api: root.getAttribute('data-api') || 'api/locker-map',
    role: (root.getAttribute('data-role') || 'END_USER').toUpperCase(),
    balance: Number(root.getAttribute('data-balance')) || 0,
    bookingUrl: root.getAttribute('data-booking-url') || 'BookingController',
    myLockerUrl: root.getAttribute('data-mylocker-url') || 'MyLockerController',
    topupUrl: root.getAttribute('data-topup-url') || 'TopupController',
    commandUrl: root.getAttribute('data-command-url') || 'RemoteCommandController',
    alertUrl: root.getAttribute('data-alert-url') || 'AlertController',
    // the map only shows OPEN tickets; the list highlights the row of ?id=
    ticketUrl: root.getAttribute('data-ticket-url') || 'MaintenanceController?status=OPEN',
    slotUrl: root.getAttribute('data-slot-url') || 'LockerSlotController'
  };

  var state = {
    data: null,
    area: readParam('area'),
    slotId: toInt(readParam('slot')),
    filters: {},
    query: '',
    loadedAt: 0,
    error: null,
    panelDirty: false,
    returnFocus: null
  };

  var overlayQuery = window.matchMedia('(max-width: 1199px)');
  var el = {};

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

  function inList(list, value) {
    return list.indexOf(value) !== -1;
  }

  function isStaff() {
    return inList(STAFF_ROLES, cfg.role);
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
    return d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit' }) + ', ' + time;
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
    var names = { ACTIVE: 'Hoạt động', MAINTENANCE: 'Bảo trì', OFFLINE: 'Mất kết nối' };
    return names[code || 'ACTIVE'] || code;
  }

  function sizeLabel(slot) {
    var names = { S: 'Nhỏ', M: 'Vừa', L: 'Lớn' };
    var text = names[slot.size] || slot.size || '-';
    return slot.size_cm ? text + ' (' + esc(slot.size_cm) + ' cm)' : text;
  }

  function currentArea() {
    return state.data && state.data.area ? state.data.area : null;
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

  function syncUrl() {
    try {
      var parts = [];
      if (state.area) {
        parts.push('area=' + encodeURIComponent(state.area));
      }
      if (state.slotId !== null) {
        parts.push('slot=' + state.slotId);
      }
      window.history.replaceState(null, '', window.location.pathname + (parts.length ? '?' + parts.join('&') : ''));
    } catch (e) {
      // some browsers refuse replaceState (private mode, file://); the page works without it
    }
  }

  /* ---------- skeleton, built once ---------- */

  function buildSkeleton() {
    root.innerHTML =
      '<div class="map-layout">' +
        '<aside class="area-menu" aria-label="Khu vực tủ">' +
          '<h2 class="area-menu__title">Khu vực</h2>' +
          '<div class="area-list" data-ref="areas"></div>' +
        '</aside>' +
        '<section class="map-main" aria-labelledby="areaTitle">' +
          '<div class="map-head">' +
            '<div><h1 id="areaTitle" data-ref="title">Sơ đồ tủ</h1><p class="map-sub" data-ref="sub"></p></div>' +
            '<div class="map-sync" data-ref="sync"><span class="sync-dot"></span><span data-ref="syncText">Đang tải</span>' +
              '<button type="button" class="icon-btn" data-refresh aria-label="Làm mới ngay">' + icon('refresh') + '</button></div>' +
          '</div>' +
          '<div class="map-tools">' +
            '<label class="search">' + icon('search') +
              '<input type="search" data-ref="search" placeholder="Tìm ngăn, ví dụ A01" aria-label="Tìm ngăn theo mã" autocomplete="off"></label>' +
            '<div class="status-chips" role="group" aria-label="Lọc ngăn theo trạng thái" data-ref="chips"></div>' +
          '</div>' +
          '<div class="bank-list" data-ref="banks"></div>' +
        '</section>' +
        '<aside class="slot-panel" data-ref="panel" aria-labelledby="panelTitle" tabindex="-1"></aside>' +
      '</div>' +
      '<div class="sheet-backdrop" data-ref="backdrop" hidden></div>';

    var refs = root.querySelectorAll('[data-ref]');
    for (var i = 0; i < refs.length; i++) {
      el[refs[i].getAttribute('data-ref')] = refs[i];
    }
  }

  /* ---------- rendering ---------- */

  function renderAreas() {
    var areas = (state.data && state.data.areas) || [];
    if (!areas.length) {
      el.areas.innerHTML = '<p class="muted">Chưa có khu vực tủ nào.</p>';
      return;
    }
    el.areas.innerHTML = areas.map(function (a) {
      var active = a.area_code === state.area;
      var pct = a.slot_count ? Math.round(a.available * 100 / a.slot_count) : 0;
      return '<button type="button" class="area-item' + (active ? ' is-active' : '') + '" data-area="' + esc(a.area_code) + '"' +
          (active ? ' aria-current="true"' : '') + '>' +
        '<span class="area-item__top"><span class="area-item__name">' + esc(a.name) + '</span>' +
          '<span class="area-item__code">' + esc(a.area_code) + '</span></span>' +
        '<span class="area-item__loc">' + esc(a.location) + '</span>' +
        '<span class="area-meter" aria-hidden="true"><span style="width:' + pct + '%"></span></span>' +
        '<span class="area-item__meta"><span>' + 'Trống ' + a.available + ' / ' + a.slot_count + '</span>' +
          (a.alert ? '<span class="map-tag map-tag--alert">' + a.alert + ' cảnh báo</span>' : '') +
          (a.live ? '<span class="map-tag map-tag--live">Có thiết bị</span>' : '') +
        '</span>' +
      '</button>';
    }).join('');
  }

  function renderHead() {
    var area = currentArea();
    el.title.textContent = area ? area.name : 'Sơ đồ tủ';
    el.sub.innerHTML = area ? icon('pin') + '<span>' + esc(area.location) + '</span>' : '';
  }

  function renderChips() {
    var counts = countStatuses();
    var html = STATUS_ORDER.filter(function (code) {
      return counts[code] || state.filters[code];
    }).map(function (code) {
      return '<button type="button" class="chip st-' + code + '" data-filter="' + code + '" aria-pressed="' + (state.filters[code] ? 'true' : 'false') + '">' +
        '<span class="chip__dot"></span>' + statusInfo(code).label +
        ' <span class="chip__count">' + (counts[code] || 0) + '</span></button>';
    }).join('');
    if (hasFilter()) {
      html += '<button type="button" class="chip chip--clear" data-filter-clear>Bỏ lọc</button>';
    }
    el.chips.innerHTML = html;
  }

  function deviceTag(bank) {
    if (bank.device_status === 'MAINTENANCE') {
      return '<span class="device-tag device-tag--maintenance"><span class="dot"></span>Thiết bị đang bảo trì</span>';
    }
    if (bank.device_status === 'OFFLINE') {
      return '<span class="device-tag device-tag--maintenance"><span class="dot"></span>Thiết bị mất kết nối</span>';
    }
    return '<span class="device-tag device-tag--live"><span class="dot"></span>Thiết bị trực tuyến</span>';
  }

  function slotHtml(slot) {
    var st = statusInfo(slot.status);
    var q = state.query;
    var match = q && String(slot.slot_code).toLowerCase().indexOf(q) !== -1;
    var dim = (hasFilter() && !state.filters[slot.status]) || (q && !match);
    var classes = 'slot st-' + slot.status + ' size-' + (slot.size || 'S') +
      (slot.mine ? ' is-mine' : '') + (dim ? ' is-dim' : '') + (match ? ' is-match' : '') +
      (slot.slot_id === state.slotId ? ' is-selected' : '');
    var label = slot.slot_code + ', ' + st.label + ', cỡ ' + (slot.size || 'S') + (slot.mine ? ', của bạn' : '');
    return '<button type="button" class="' + classes + '" data-slot="' + slot.slot_id + '" aria-label="' + esc(label) + '"' +
        ' aria-pressed="' + (slot.slot_id === state.slotId ? 'true' : 'false') + '" title="' + esc(label) + '">' +
      '<span class="slot__code">' + esc(slot.slot_code) + '</span>' +
      '<span class="slot__icon">' + icon(st.icon) + '</span>' +
      (slot.mine ? '<span class="slot__you">Bạn</span>' : '') +
    '</button>';
  }

  function bankFoot(bank) {
    var free = 0, used = 0, issues = 0;
    (bank.slots || []).forEach(function (s) {
      if (s.status === 'AVAILABLE') {
        free++;
      } else if (s.status === 'OCCUPIED' || s.status === 'RESERVED' || s.status === 'OVERDUE') {
        used++;
      } else {
        issues++;
      }
    });
    return free + ' trống · ' + used + ' đang dùng' + (issues ? ' · ' + issues + ' cần kiểm tra' : '');
  }

  function renderBanks() {
    var list = banks();
    if (!state.data) {
      el.banks.innerHTML = '<div class="empty">Đang tải dãy tủ…</div>';
      return;
    }
    if (!list.length) {
      el.banks.innerHTML = '<div class="empty">Khu vực này chưa có dãy tủ nào.</div>';
      return;
    }
    el.banks.innerHTML = list.map(function (bank) {
      return '<article class="bank" aria-label="' + esc(bank.name + ' ' + bank.bank_code) + '">' +
        '<header class="bank__head"><h2 class="bank__name">' + esc(bank.name) +
          (bank.name !== bank.bank_code ? '<span class="bank__code">' + esc(bank.bank_code) + '</span>' : '') +
          '</h2>' + deviceTag(bank) + '</header>' +
        '<div class="bank__scroll"><div class="cabinet" style="--rows:' + (toInt(bank.rows) || 4) + '">' +
          (bank.slots || []).map(slotHtml).join('') +
        '</div></div>' +
        '<p class="bank__foot">' + bankFoot(bank) + '</p>' +
      '</article>';
    }).join('');
  }

  function renderSync() {
    var text;
    if (state.error) {
      text = 'Mất kết nối, đang thử lại';
    } else if (!state.loadedAt) {
      text = 'Đang tải';
    } else {
      var secs = Math.max(0, Math.round((Date.now() - state.loadedAt) / 1000));
      text = secs < 3 ? 'Vừa cập nhật' : 'Cập nhật ' + secs + ' giây trước';
    }
    el.syncText.textContent = text;
    el.sync.classList.toggle('is-error', !!state.error);
  }

  function legendHtml() {
    return '<ul class="legend">' + STATUS_ORDER.map(function (code) {
      var st = statusInfo(code);
      return '<li><span class="swatch st-' + code + '">' + icon(st.icon) + '</span>' + st.label + '</li>';
    }).join('') + '</ul>';
  }

  function describe(slot, bank) {
    var mine = slot.mine;
    switch (slot.status) {
      case 'AVAILABLE':
        return 'Chọn gói gửi và đặt ngăn này.';
      case 'RESERVED':
        return mine ? 'Ngăn đang giữ cho bạn. Hãy đến gửi đồ trước khi hết thời gian giữ, nếu không ngăn sẽ được trả lại.'
                    : 'Ngăn này đã có người đặt.';
      case 'OCCUPIED':
        return mine ? 'Đồ của bạn đang ở trong ngăn.' : 'Đang có người dùng.';
      case 'OVERDUE':
        return mine ? 'Đã hết thời gian gửi. Hãy gia hạn hoặc đến lấy đồ.' : 'Đã hết thời gian gửi.';
      case 'ALERT':
        return 'Ngăn này đang có cảnh báo, nhân viên đang kiểm tra.';
      case 'MAINTENANCE':
        return 'Tạm ngưng sử dụng trong lúc kỹ thuật viên kiểm tra.';
      case 'OFFLINE':
        return 'Bộ điều khiển tủ đang mất kết nối nên trạng thái có thể chưa cập nhật.';
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
  function formStart(url, action, slot, confirmText) {
    return '<form class="action-form" method="post" action="' + esc(url) + '"' +
      (confirmText ? ' data-confirm="' + esc(confirmText) + '"' : '') + '>' +
      (action ? hidden('action', action) : '') +
      hidden('slotId', slot.slot_id) + hidden('area', state.area) + hidden('slot', slot.slot_id);
  }

  var METHODS = {
    PIN: { label: 'Mật mã', desc: 'Nhập 6 số trên bàn phím của hộp hoặc trên điện thoại (quét QR).' },
    CARD: { label: 'Thẻ từ', desc: 'Quẹt thẻ tại hộp, giảm 5% giá gói.' },
    FINGERPRINT: { label: 'Vân tay', desc: 'Đặt ngón tay lên cảm biến của hộp.' }
  };
  var METHOD_ORDER = ['PIN', 'CARD', 'FINGERPRINT'];

  function money(n) {
    return (Number(n) || 0).toLocaleString('vi-VN') + ' đ';
  }

  function holdMinutes() {
    return (state.data && state.data.hold_min) || HOLD_MINUTES;
  }

  function cardDepositDue() {
    return !!(state.data && state.data.card_deposit_due);
  }

  function cardDeposit() {
    return (state.data && state.data.card_deposit) || 30000;
  }

  // the card is 5% off, rounded up to 100 VND (util.Pricing); the server sends price_card, this is only a fallback
  function planPrice(plan, method) {
    var base = Number(plan.price) || 0;
    if (method !== 'CARD') {
      return base;
    }
    return plan.price_card !== undefined ? Number(plan.price_card) : Math.ceil(base * 95 / 10000) * 100;
  }

  function fingerEnrolled(bank) {
    var list = (state.data && state.data.fp_devices) || [];
    return !!bank.device_code && list.indexOf(bank.device_code) !== -1;
  }

  function methodDesc(code, bank) {
    if (code === 'CARD' && cardDepositDue()) {
      return METHODS.CARD.desc + ' Cọc ' + money(cardDeposit()) + ' lần đầu.';
    }
    if (code === 'FINGERPRINT') {
      return METHODS.FINGERPRINT.desc + (fingerEnrolled(bank) ? ' Bạn đã đăng ký vân tay trên hộp này.'
        : ' Lần đầu cần đăng ký tại hộp bằng mã ở trang Tủ của tôi.');
    }
    return METHODS[code].desc;
  }

  // what the user is choosing: plan, open method, price now, and the card deposit taken when the card is enrolled
  function reserveChoice() {
    var select = el.panel.querySelector('[data-plan-select]');
    var plans = (state.data && state.data.plans) || [];
    if (!select || !plans.length) {
      return null;
    }
    var plan = plans[select.selectedIndex] || plans[0];
    var checked = el.panel.querySelector('input[name="openMethod"]:checked');
    var method = checked ? checked.value : 'PIN';
    var price = planPrice(plan, method);
    var deposit = method === 'CARD' && cardDepositDue() ? cardDeposit() : 0;
    return { plan: plan, method: method, price: price, deposit: deposit, total: price + deposit };
  }

  function reserveForm(slot, bank) {
    var plans = (state.data && state.data.plans) || [];
    if (!plans.length) {
      return '<p class="notice notice--warn">Hiện chưa có gói gửi nào.</p>';
    }
    var options = plans.map(function (p) {
      var price = p.price ? ' · ' + money(p.price) : ' · Miễn phí';
      return '<option value="' + esc(p.plan_id) + '">' + esc(p.plan_name + price) + '</option>';
    }).join('');
    var radios = METHOD_ORDER.map(function (code, i) {
      var id = 'om-' + slot.slot_id + '-' + code;
      return '<label class="method-opt" for="' + id + '">' +
        '<input type="radio" id="' + id + '" name="openMethod" value="' + code + '"' + (i === 0 ? ' checked' : '') + '>' +
        '<span><span class="method-opt__name">' + esc(METHODS[code].label) + '</span>' +
          '<span class="method-opt__desc">' + esc(methodDesc(code, bank)) + '</span></span>' +
        '<span class="method-opt__price" data-price-for="' + code + '"></span>' +
      '</label>';
    }).join('');
    return formStart(cfg.bookingUrl, 'reserve', slot) +
      '<h3>Đặt ngăn này</h3>' +
      '<label class="field"><span>Gói gửi</span><select name="planId" data-plan-select>' + options + '</select></label>' +
      '<fieldset class="method-pick"><legend>Cách mở tủ</legend>' + radios + '</fieldset>' +
      '<p class="hint">Số dư ví: <strong data-account-balance></strong></p>' +
      '<button type="submit" class="btn btn--primary btn--block" data-reserve-button>' +
        icon('bookmark') + 'Đặt ngăn</button>' +
      '<p class="notice notice--warn" data-balance-warning hidden>Số dư không đủ. ' +
        '<a href="' + esc(cfg.topupUrl) + '">Nạp tiền</a></p>' +
      '<p class="hint">Ngăn được giữ trong ' + holdMinutes() + ' phút. Hủy trước khi gửi đồ được hoàn đủ; ' +
        'không đến trong thời gian giữ sẽ mất 10% (hoàn 90% vào ví). ' +
        'Không đến 3 lần trong 7 ngày sẽ bị tạm khóa đặt trực tuyến.</p>' +
    '</form>';
  }

  function updateReserveForm() {
    var choice = reserveChoice();
    if (!choice) {
      return;
    }
    METHOD_ORDER.forEach(function (code) {
      var node = el.panel.querySelector('[data-price-for="' + code + '"]');
      if (!node) {
        return;
      }
      var p = planPrice(choice.plan, code);
      var base = Number(choice.plan.price) || 0;
      node.innerHTML = (p ? esc(money(p)) : 'Miễn phí') +
        (code === 'CARD' && p < base ? '<s>' + esc(money(base)) + '</s>' : '');
    });
    var balance = Math.max(0, Number(cfg.balance) || 0);
    var insufficient = cfg.source === 'api' && choice.total > balance;
    el.panel.querySelector('[data-account-balance]').textContent = money(balance);
    var button = el.panel.querySelector('[data-reserve-button]');
    button.disabled = insufficient;
    button.innerHTML = icon('bookmark') + (choice.total ? 'Đặt ngăn · ' + esc(money(choice.total)) : 'Đặt miễn phí');
    el.panel.querySelector('[data-balance-warning]').hidden = !insufficient;
  }

  // the popup of spec 5.1: total, open method and the no-show rule, before any money is taken
  function reserveConfirmHtml(slot, bank, choice) {
    var discounted = choice.method === 'CARD' && choice.price < (Number(choice.plan.price) || 0);
    var rows = [
      ['Ngăn', esc(slot.slot_code) + ' <span class="muted">' + esc(bank.bank_code) + '</span>'],
      ['Gói gửi', esc(choice.plan.plan_name)],
      ['Cách mở', esc(METHODS[choice.method].label)],
      ['Giá gói', (choice.price ? esc(money(choice.price)) : 'Miễn phí') +
        (discounted ? ' <span class="muted">(đã giảm 5%)</span>' : '')]
    ];
    if (choice.deposit) {
      rows.push(['Cọc thẻ', esc(money(choice.deposit)) + ' <span class="muted">(trừ khi đăng ký thẻ tại hộp)</span>']);
      rows.push(['Trả ngay', esc(money(choice.price))]);
    }
    rows.push(['Tổng', '<strong class="dlg__total money">' + esc(money(choice.total)) + '</strong>']);
    return '<dl class="kv">' + rows.map(function (r) {
        return '<dt>' + r[0] + '</dt><dd>' + r[1] + '</dd>';
      }).join('') + '</dl>' +
      '<p class="notice">Giữ chỗ ' + holdMinutes() + ' phút; không đến sẽ mất 10%.</p>';
  }

  function cancelForm(slot) {
    return formStart(cfg.bookingUrl, 'cancel', slot, 'Hủy lượt đặt ngăn ' + slot.slot_code + '?') +
      hidden('depositId', slot.deposit_id) +
      '<button type="submit" class="btn ghost btn--block">Hủy đặt</button>' +
    '</form>';
  }

  function extendForm(slot) {
    return formStart(cfg.bookingUrl, 'extend', slot) +
      hidden('depositId', slot.deposit_id) +
      '<h3>Gia hạn trực tuyến</h3>' +
      '<label class="field"><span>Thêm thời gian</span><select name="minutes">' +
        '<option value="30">30 phút</option><option value="60" selected>1 giờ</option><option value="120">2 giờ</option>' +
      '</select></label>' +
      '<button type="submit" class="btn btn--primary btn--block">' + icon('clock') + 'Gia hạn</button>' +
    '</form>';
  }

  function unlockForm(slot, bank) {
    var online = bank.device_status === 'ACTIVE';
    var confirmText = 'Mở khóa ngăn ' + slot.slot_code + ' (' + bank.bank_code + ') ngay? ' +
      'Cửa sẽ mở trong khoảng 10 giây và thao tác được ghi vào nhật ký.';
    return formStart(cfg.commandUrl, null, slot, confirmText) +
      '<h3>Mở khóa từ xa</h3>' +
      '<label class="field"><span>Lý do</span>' +
        '<textarea name="reason" required minlength="5" maxlength="200" placeholder="Ví dụ: Sinh viên quên thẻ, đã kiểm tra CCCD tại quầy"' +
        (online ? '' : ' disabled') + '></textarea></label>' +
      '<button type="submit" class="btn btn--danger btn--block"' + (online ? '' : ' disabled') + '>' + icon('unlock') + 'Mở khóa ngay</button>' +
      (online ? '<p class="hint">Mỗi thiết bị chỉ do một nhân viên điều khiển tại một thời điểm.</p>'
              : '<p class="notice notice--warn">Thiết bị không trực tuyến nên không gửi được lệnh.</p>') +
    '</form>';
  }

  function statusForm(slot, bank) {
    var cur = slot.status;
    return '<form class="action-form" method="post" action="' + esc(cfg.slotUrl) + '">' +
      hidden('action', 'status') +
      hidden('id', slot.slot_id) +
      hidden('back', 'map') +
      hidden('area', state.area) +
      hidden('slot', slot.slot_id) +
      '<h3>Đổi trạng thái ngăn</h3>' +
      '<label class="field"><span>Trạng thái</span><select name="status">' +
        '<option value="AVAILABLE"' + (cur === 'AVAILABLE' ? ' selected' : '') + '>Trống</option>' +
        '<option value="MAINTENANCE"' + (cur === 'MAINTENANCE' ? ' selected' : '') + '>Bảo trì (ngưng sử dụng)</option>' +
        (cur === 'OCCUPIED' ? '<option value="OCCUPIED" selected>Đang dùng</option>' : '') +
        (cur === 'RESERVED' ? '<option value="RESERVED" selected>Đã đặt</option>' : '') +
      '</select></label>' +
      '<button type="submit" class="btn btn--primary btn--block">' + icon('check') + 'Cập nhật trạng thái</button>' +
    '</form>';
  }

  function linkButton(url, id, text) {
    var href = url + (url.indexOf('?') === -1 ? '?' : '&') + 'id=' + encodeURIComponent(id);
    return '<a class="btn ghost btn--block" href="' + esc(href) + '">' + esc(text) + '</a>';
  }

  function actionsHtml(slot, bank) {
    var role = cfg.role;
    var parts = [];
    if (slot.alert && inList(ALERT_READERS, role)) {
      parts.push(linkButton(cfg.alertUrl, slot.alert.alert_id, 'Xem cảnh báo #' + slot.alert.alert_id));
    }
    if (slot.ticket_id && inList(ALERT_READERS, role)) {
      parts.push(linkButton(cfg.ticketUrl, slot.ticket_id, 'Xem phiếu bảo trì #' + slot.ticket_id));
    }

    if (role === 'END_USER') {
      if (slot.status === 'AVAILABLE') {
        parts.push(reserveForm(slot, bank));
      } else if (slot.mine && slot.status === 'RESERVED') {
        parts.push('<a class="btn btn--block" href="' + esc(cfg.myLockerUrl) + '">' + icon('unlock') + 'Xem cách mở ở Tủ của tôi</a>');
        parts.push(cancelForm(slot));
      } else if (slot.mine && (slot.status === 'OCCUPIED' || slot.status === 'OVERDUE')) {
        parts.push(extendForm(slot));
      }
    } else if (isStaff()) {
      parts.push(unlockForm(slot, bank));
      parts.push(statusForm(slot, bank));
    } else if (role === 'AUDITOR') {
      parts.push('<p class="notice">Chỉ được xem. Mọi lần mở khóa từ xa đều có trong nhật ký kiểm toán.</p>');
    }
    return parts.join('');
  }

  // Prices are shown before the user pays from the account balance.
  function priceHtml() {
    var plans = (state.data && state.data.plans) || [];
    if (!plans.length) {
      return '';
    }
    return plans.map(function (p) {
      var amount = p.price ? Number(p.price).toLocaleString('vi-VN') + ' đ' : 'Miễn phí';
      return '<span class="price-row"><span>' + esc(p.plan_name) + '</span><strong>' + amount + '</strong></span>';
    }).join('');
  }

  function panelHtml(found) {
    var slot = found.slot;
    var bank = found.bank;
    var st = statusInfo(slot.status);
    var area = currentArea();
    var facts = [
      fact('Kích cỡ', sizeLabel(slot)),
      fact('Dãy tủ', esc(bank.name) + ' <span class="muted">' + esc(bank.bank_code) + '</span>'),
      fact('Thiết bị', esc(deviceLabel(bank.device_status)))
    ];
    var prices = priceHtml();
    if (prices) {
      facts.splice(1, 0, fact('Giá', '<span class="price-list">' + prices + '</span>'));
    }
    if (slot.status === 'RESERVED' && slot.hold_until) {
      facts.push(fact(slot.mine ? 'Giữ cho bạn đến' : 'Giữ đến', formatTime(slot.hold_until) + countdownHtml(slot.hold_until)));
    }
    if ((slot.status === 'OCCUPIED' || slot.status === 'OVERDUE') && slot.due_at) {
      facts.push(fact('Hạn trả', formatTime(slot.due_at) + countdownHtml(slot.due_at)));
    }
    if (slot.occupant && cfg.role !== 'END_USER') {
      facts.push(fact('Người dùng', esc(slot.occupant)));
    }
    if (slot.alert && inList(ALERT_READERS, cfg.role)) {
      facts.push(fact('Cảnh báo', esc(slot.alert.label)));
    }
    return '<div class="panel-head"><div>' +
        '<p class="panel-kicker">' + esc(area ? area.name : '') + '</p>' +
        '<h2 class="panel-title" id="panelTitle" tabindex="-1">Ngăn ' + esc(slot.slot_code) + '</h2></div>' +
        '<button type="button" class="icon-btn" data-close aria-label="Đóng chi tiết">' + icon('close') + '</button>' +
      '</div>' +
      '<span class="status-pill st-' + esc(slot.status) + '">' + icon(st.icon) + st.label + (slot.mine ? ' · của bạn' : '') + '</span>' +
      '<p class="panel-desc">' + describe(slot, bank) + '</p>' +
      '<dl class="facts">' + facts.join('') + '</dl>' +
      '<div class="panel-actions">' + actionsHtml(slot, bank) + '</div>';
  }

  function renderPanel(force) {
    var found = state.slotId !== null && state.data ? findSlot(state.slotId) : null;
    if (!found) {
      if (state.data) {
        state.slotId = null;   // before the first load, keep the slot asked for in the URL
      }
      closeOverlay(false);
      el.panel.innerHTML = '<div class="panel-empty"><h2>Chọn một ngăn</h2>' +
        '<p>Bấm vào một cửa tủ để xem trạng thái và các thao tác có thể làm.</p>' + legendHtml() + '</div>';
      state.panelDirty = false;
      return;
    }
    // keep what the user is typing when a background refresh arrives
    if (state.panelDirty && !force) {
      return;
    }
    el.panel.innerHTML = panelHtml(found);
    updateReserveForm();
    state.panelDirty = false;
  }

  function renderAll() {
    renderAreas();
    renderHead();
    renderChips();
    renderBanks();
    renderPanel(false);
    renderSync();
  }

  /* ---------- overlay (drawer / bottom sheet) ---------- */

  function openOverlay() {
    if (!overlayQuery.matches) {
      return;
    }
    el.panel.classList.add('is-open');
    el.panel.setAttribute('role', 'dialog');
    el.panel.setAttribute('aria-modal', 'true');
    el.backdrop.hidden = false;
    document.body.classList.add('sheet-open');
  }

  function closeOverlay(restoreFocus) {
    el.panel.classList.remove('is-open');
    el.panel.removeAttribute('role');
    el.panel.removeAttribute('aria-modal');
    el.backdrop.hidden = true;
    document.body.classList.remove('sheet-open');
    if (restoreFocus && state.returnFocus) {
      var target = root.querySelector('[data-slot="' + state.returnFocus + '"]');
      if (target) {
        target.focus();
      }
    }
  }

  function selectSlot(id) {
    state.slotId = id;
    state.returnFocus = id;
    renderBanks();
    renderPanel(true);
    syncUrl();
    openOverlay();
    var title = document.getElementById('panelTitle');
    if (title && overlayQuery.matches) {
      title.focus();
    }
  }

  function clearSelection() {
    state.slotId = null;
    closeOverlay(true);
    renderBanks();
    renderPanel(true);
    syncUrl();
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
    state.data = normalize(data);
    if (data.balance !== undefined && data.balance !== null) {
      cfg.balance = Number(data.balance) || 0;
    }
    state.error = null;
    state.loadedAt = Date.now();
    if (data.area && data.area.area_code) {
      state.area = data.area.area_code;
    }
    renderAll();
    updateReserveForm();
    if (state.slotId !== null && findSlot(state.slotId)) {
      openOverlay();
    }
  }

  function load() {
    var url = cfg.api + (cfg.api.indexOf('?') === -1 ? '?' : '&') + 'area=' + encodeURIComponent(state.area || '');
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
      .then(onData)
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
    var target = e.target.closest('[data-area],[data-slot],[data-filter],[data-filter-clear],[data-close],[data-refresh]');
    if (!target) {
      return;
    }
    if (target.hasAttribute('data-area')) {
      var code = target.getAttribute('data-area');
      if (code !== state.area) {
        state.area = code;
        state.slotId = null;
        state.filters = {};
        if (state.data) {
          state.data.banks = [];
        }
        closeOverlay(false);
        renderAreas();
        renderBanks();
        syncUrl();
        load();
      }
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
    }
  }

  // the confirm popup of js/app.js; on OK the form is submitted again with data-confirmed="1"
  function askFirst(form, opts, submitter) {
    state.panelDirty = true;   // the 10 s refresh must not replace this form while the popup is open
    window.SmartLocker.confirm(opts).then(function (yes) {
      if (!yes) {
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
    var isReserve = !!form.querySelector('[data-plan-select]');
    var needsConfirm = isReserve || form.hasAttribute('data-confirm');
    if (needsConfirm && form.getAttribute('data-confirmed') !== '1' && window.SmartLocker && window.SmartLocker.confirm) {
      e.preventDefault();
      if (isReserve) {
        var found = findSlot(toInt(form.querySelector('[name="slotId"]').value));
        var choice = reserveChoice();
        if (!found || !choice) {
          return;
        }
        askFirst(form, {
          title: 'Xác nhận đặt ngăn ' + found.slot.slot_code,
          html: reserveConfirmHtml(found.slot, found.bank, choice),
          okText: choice.price ? 'Đặt và trả ' + money(choice.price) : 'Đặt ngăn'   // the card deposit is taken later, at the box
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
    // js/app.js clears data-confirmed for forms with data-confirm; the reserve form has none
    if (isReserve) {
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
      if (e.target.hasAttribute('data-plan-select') || e.target.name === 'openMethod') {
        updateReserveForm();
      }
    });
    el.backdrop.addEventListener('click', clearSelection);
    el.search.addEventListener('input', function () {
      state.query = el.search.value.trim().toLowerCase();
      renderBanks();
    });
    el.search.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') {
        return;
      }
      var matches = root.querySelectorAll('.slot.is-match');
      if (matches.length === 1) {
        selectSlot(toInt(matches[0].getAttribute('data-slot')));
      }
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && el.panel.classList.contains('is-open')) {
        clearSelection();
      }
    });
    var onLayoutChange = function () {
      if (!overlayQuery.matches) {
        closeOverlay(false);
      } else if (state.slotId !== null) {
        openOverlay();
      }
    };
    if (overlayQuery.addEventListener) {
      overlayQuery.addEventListener('change', onLayoutChange);
    } else {
      overlayQuery.addListener(onLayoutChange);
    }
  }

  function tick() {
    renderSync();
    var nodes = el.panel.querySelectorAll('[data-countdown]');
    for (var i = 0; i < nodes.length; i++) {
      var c = formatCountdown(nodes[i].getAttribute('data-countdown'));
      nodes[i].textContent = c.text;
      nodes[i].classList.toggle('is-late', c.late);
    }
  }

  /* ---------- start ---------- */

  buildSkeleton();
  bindEvents();
  renderAll();
  load();
  setInterval(tick, 1000);
  setInterval(function () {
    if (!document.hidden) {
      load();
    }
  }, REFRESH_MS);
})();
