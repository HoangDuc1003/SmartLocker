/* Locker map: area menu, locker banks and the slot detail panel.
   Data source is set on <main id="lockerApp">:
     data-source="api"  -> GET data-api?area=CODE, refreshed every 10 seconds (real pages)
     data-source="mock" -> window.LOCKER_MOCK (preview/index.html only)
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
    AVAILABLE: { label: 'Available', icon: 'check' },
    RESERVED: { label: 'Reserved', icon: 'bookmark' },
    OCCUPIED: { label: 'Occupied', icon: 'lock' },
    OVERDUE: { label: 'Overdue', icon: 'clock' },
    ALERT: { label: 'Alert', icon: 'alert' },
    MAINTENANCE: { label: 'Maintenance', icon: 'wrench' },
    OFFLINE: { label: 'Offline', icon: 'wifiOff' }
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
    source: root.getAttribute('data-source') || 'api',
    api: root.getAttribute('data-api') || 'api/locker-map',
    role: (root.getAttribute('data-role') || 'END_USER').toUpperCase(),
    balance: Number(root.getAttribute('data-balance')) || 0,
    bookingUrl: root.getAttribute('data-booking-url') || 'BookingController',
    topupUrl: root.getAttribute('data-topup-url') || 'TopupController',
    commandUrl: root.getAttribute('data-command-url') || 'RemoteCommandController',
    alertUrl: root.getAttribute('data-alert-url') || 'AlertController',
    ticketUrl: root.getAttribute('data-ticket-url') || 'MaintenanceController',
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

  function esc(value) {
    return String(value === null || value === undefined ? '' : value)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

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

  function formatTime(iso) {
    if (!iso) {
      return '';
    }
    var d = new Date(iso);
    if (isNaN(d.getTime())) {
      return esc(iso);
    }
    var time = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    var today = new Date();
    if (d.toDateString() === today.toDateString()) {
      return time;
    }
    return d.toLocaleDateString([], { day: '2-digit', month: 'short' }) + ', ' + time;
  }

  // "12:34 left" under an hour, "2h 05m left" above, "late 5m" when the time has passed
  function formatCountdown(iso) {
    var diff = Math.round((new Date(iso).getTime() - Date.now()) / 1000);
    var late = diff < 0;
    var s = Math.abs(diff);
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var text = h > 0 ? h + 'h ' + (m < 10 ? '0' : '') + m + 'm'
                     : m + ':' + (sec < 10 ? '0' : '') + sec;
    return { text: late ? 'late ' + text : text + ' left', late: late };
  }

  function countdownHtml(iso) {
    var c = formatCountdown(iso);
    return '<span class="countdown' + (c.late ? ' is-late' : '') + '" data-countdown="' + esc(iso) + '">' + esc(c.text) + '</span>';
  }

  function sizeLabel(slot) {
    var names = { S: 'Small', M: 'Medium', L: 'Large' };
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
      // file:// previews may refuse replaceState, the page works without it
    }
  }

  /* ---------- skeleton, built once ---------- */

  function buildSkeleton() {
    root.innerHTML =
      '<div class="map-layout">' +
        '<aside class="area-menu" aria-label="Locker areas">' +
          '<h2 class="area-menu__title">Areas</h2>' +
          '<div class="area-list" data-ref="areas"></div>' +
        '</aside>' +
        '<section class="map-main" aria-labelledby="areaTitle">' +
          '<div class="map-head">' +
            '<div><h1 id="areaTitle" data-ref="title">Locker map</h1><p class="map-sub" data-ref="sub"></p></div>' +
            '<div class="map-sync" data-ref="sync"><span class="sync-dot"></span><span data-ref="syncText">Loading</span>' +
              '<button type="button" class="icon-btn" data-refresh aria-label="Refresh now">' + icon('refresh') + '</button></div>' +
          '</div>' +
          '<div class="map-tools">' +
            '<label class="search">' + icon('search') +
              '<input type="search" data-ref="search" placeholder="Find a slot, e.g. A01" aria-label="Find a slot by code" autocomplete="off"></label>' +
            '<div class="status-chips" role="group" aria-label="Filter slots by status" data-ref="chips"></div>' +
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
      el.areas.innerHTML = '<p class="muted">No locker areas yet.</p>';
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
        '<span class="area-item__meta"><span>' + a.available + ' / ' + a.slot_count + ' free</span>' +
          (a.alert ? '<span class="map-tag map-tag--alert">' + a.alert + ' alert' + (a.alert > 1 ? 's' : '') + '</span>' : '') +
          (a.live ? '<span class="map-tag map-tag--live">Live</span>' : '') +
        '</span>' +
      '</button>';
    }).join('');
  }

  function renderHead() {
    var area = currentArea();
    el.title.textContent = area ? area.name : 'Locker map';
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
      html += '<button type="button" class="chip chip--clear" data-filter-clear>Clear filter</button>';
    }
    el.chips.innerHTML = html;
  }

  function deviceTag(bank) {
    if (bank.device_status === 'MAINTENANCE') {
      return '<span class="device-tag device-tag--maintenance"><span class="dot"></span>Device maintenance</span>';
    }
    if (bank.device_status === 'OFFLINE') {
      return '<span class="device-tag device-tag--maintenance"><span class="dot"></span>Device offline</span>';
    }
    return '<span class="device-tag device-tag--live"><span class="dot"></span>Live device</span>';
  }

  function slotHtml(slot) {
    var st = statusInfo(slot.status);
    var q = state.query;
    var match = q && String(slot.slot_code).toLowerCase().indexOf(q) !== -1;
    var dim = (hasFilter() && !state.filters[slot.status]) || (q && !match);
    var classes = 'slot st-' + slot.status + ' size-' + (slot.size || 'S') +
      (slot.mine ? ' is-mine' : '') + (dim ? ' is-dim' : '') + (match ? ' is-match' : '') +
      (slot.slot_id === state.slotId ? ' is-selected' : '');
    var label = slot.slot_code + ', ' + st.label + ', size ' + (slot.size || 'S') + (slot.mine ? ', yours' : '');
    return '<button type="button" class="' + classes + '" data-slot="' + slot.slot_id + '" aria-label="' + esc(label) + '"' +
        ' aria-pressed="' + (slot.slot_id === state.slotId ? 'true' : 'false') + '" title="' + esc(label) + '">' +
      '<span class="slot__code">' + esc(slot.slot_code) + '</span>' +
      '<span class="slot__icon">' + icon(st.icon) + '</span>' +
      (slot.mine ? '<span class="slot__you">You</span>' : '') +
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
    return free + ' free · ' + used + ' in use' + (issues ? ' · ' + issues + ' need attention' : '');
  }

  function renderBanks() {
    var list = banks();
    if (!state.data) {
      el.banks.innerHTML = '<div class="empty">Loading locker banks…</div>';
      return;
    }
    if (!list.length) {
      el.banks.innerHTML = '<div class="empty">No locker banks in this area yet.</div>';
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
      text = 'Connection problem, retrying';
    } else if (cfg.source === 'mock') {
      text = 'Preview data';
    } else if (!state.loadedAt) {
      text = 'Loading';
    } else {
      var secs = Math.max(0, Math.round((Date.now() - state.loadedAt) / 1000));
      text = secs < 3 ? 'Updated just now' : 'Updated ' + secs + 's ago';
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
        return 'Choose a storage plan and reserve this slot.';
      case 'RESERVED':
        return mine ? 'Reserved for you. Check in before the hold ends, or the slot is released.'
                    : 'Someone has reserved this slot.';
      case 'OCCUPIED':
        return mine ? 'Your items are inside.' : 'In use.';
      case 'OVERDUE':
        return mine ? 'Your storage time is over. Extend it now or collect your items.' : 'Storage time is over.';
      case 'ALERT':
        return 'An alert is open for this slot. Staff are checking it.';
      case 'MAINTENANCE':
        return 'Out of service while a technician checks it.';
      case 'OFFLINE':
        return 'The locker device is offline, so this status may be out of date.';
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

  function reserveForm(slot) {
    var plans = (state.data && state.data.plans) || [];
    if (!plans.length) {
      return '<p class="notice notice--warn">No storage plans are available.</p>';
    }
    var options = plans.map(function (p) {
      var price = p.price ? ' · ' + Number(p.price).toLocaleString() + ' VND' : '';
      return '<option value="' + esc(p.plan_id) + '" data-price="' + esc(p.price || 0) + '">' +
        esc(p.plan_name) + price + '</option>';
    }).join('');
    return formStart(cfg.bookingUrl, 'reserve', slot) +
      '<h3>Reserve this slot</h3>' +
      (plans.length ? '<label class="field"><span>Storage plan</span><select name="planId" data-plan-select>' + options + '</select></label>' : '') +
      '<p class="hint">Account balance: <strong data-account-balance></strong></p>' +
      '<button type="submit" class="btn btn--primary btn--block" data-reserve-button>' +
        icon('bookmark') + 'Reserve and pay</button>' +
      '<p class="notice notice--warn" data-balance-warning hidden>Insufficient balance. ' +
        '<a href="' + esc(cfg.topupUrl) + '">Add funds</a></p>' +
      '<p class="hint">The slot is held for ' + HOLD_MINUTES +
        ' minutes. Payments are refunded if you cancel before check-in or the hold expires. ' +
        'Three no-shows in 7 days pause online booking.</p>' +
    '</form>';
  }

  function updateReserveForm() {
    var form = el.panel.querySelector('[data-plan-select]');
    if (!form) {
      return;
    }
    var selected = form.options[form.selectedIndex];
    var price = selected ? Number(selected.getAttribute('data-price')) || 0 : 0;
    var balance = Math.max(0, Number(cfg.balance) || 0);
    var insufficient = cfg.source === 'api' && price > balance;
    el.panel.querySelector('[data-account-balance]').textContent =
      balance.toLocaleString() + ' VND';
    var button = el.panel.querySelector('[data-reserve-button]');
    button.disabled = insufficient;
    button.innerHTML = icon('bookmark') + (price ? 'Reserve and pay ' +
      price.toLocaleString() + ' VND' : 'Reserve for free');
    el.panel.querySelector('[data-balance-warning]').hidden = !insufficient;
  }

  function cancelForm(slot) {
    return formStart(cfg.bookingUrl, 'cancel', slot, 'Cancel your reservation for slot ' + slot.slot_code + '?') +
      hidden('depositId', slot.deposit_id) +
      '<button type="submit" class="btn ghost btn--block">Cancel reservation</button>' +
    '</form>';
  }

  function extendForm(slot) {
    return formStart(cfg.bookingUrl, 'extend', slot) +
      hidden('depositId', slot.deposit_id) +
      '<h3>Extend online</h3>' +
      '<label class="field"><span>Add time</span><select name="minutes">' +
        '<option value="30">30 minutes</option><option value="60" selected>1 hour</option><option value="120">2 hours</option>' +
      '</select></label>' +
      '<button type="submit" class="btn btn--primary btn--block">' + icon('clock') + 'Extend</button>' +
    '</form>';
  }

  function unlockForm(slot, bank) {
    var online = bank.device_status === 'ACTIVE';
    var confirmText = 'Unlock slot ' + slot.slot_code + ' (' + bank.bank_code + ') now? ' +
      'The door opens within 10 seconds and this action is logged.';
    return formStart(cfg.commandUrl, null, slot, confirmText) +
      '<h3>Remote unlock</h3>' +
      '<label class="field"><span>Reason</span>' +
        '<textarea name="reason" required minlength="5" maxlength="200" placeholder="e.g. Student forgot card, ID checked at the desk"' +
        (online ? '' : ' disabled') + '></textarea></label>' +
      '<button type="submit" class="btn btn--danger btn--block"' + (online ? '' : ' disabled') + '>' + icon('unlock') + 'Unlock now</button>' +
      (online ? '<p class="hint">Only one operator can control a device at a time.</p>'
              : '<p class="notice notice--warn">The device is not online, so the command cannot be delivered.</p>') +
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
      '<h3>Set slot status</h3>' +
      '<label class="field"><span>Status</span><select name="status">' +
        '<option value="AVAILABLE"' + (cur === 'AVAILABLE' ? ' selected' : '') + '>AVAILABLE (Free / Green)</option>' +
        '<option value="MAINTENANCE"' + (cur === 'MAINTENANCE' ? ' selected' : '') + '>MAINTENANCE (Out of service)</option>' +
        (cur === 'OCCUPIED' ? '<option value="OCCUPIED" selected>OCCUPIED (In use)</option>' : '') +
        (cur === 'RESERVED' ? '<option value="RESERVED" selected>RESERVED</option>' : '') +
      '</select></label>' +
      '<button type="submit" class="btn btn--primary btn--block">' + icon('check') + 'Update status</button>' +
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
      parts.push(linkButton(cfg.alertUrl, slot.alert.alert_id, 'Open alert #' + slot.alert.alert_id));
    }
    if (slot.ticket_id && inList(ALERT_READERS, role)) {
      parts.push(linkButton(cfg.ticketUrl, slot.ticket_id, 'Open maintenance ticket #' + slot.ticket_id));
    }

    if (role === 'END_USER') {
      if (slot.status === 'AVAILABLE') {
        parts.push(reserveForm(slot));
      } else if (slot.mine && slot.status === 'RESERVED') {
        parts.push(cancelForm(slot));
      } else if (slot.mine && (slot.status === 'OCCUPIED' || slot.status === 'OVERDUE')) {
        parts.push(extendForm(slot));
      }
    } else if (isStaff()) {
      parts.push(unlockForm(slot, bank));
      parts.push(statusForm(slot, bank));
    } else if (role === 'AUDITOR') {
      parts.push('<p class="notice">Read-only access. Every remote unlock is listed in the audit log.</p>');
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
      var amount = p.price ? Number(p.price).toLocaleString() + ' VND' : 'Free';
      return '<span class="price-row"><span>' + esc(p.plan_name) + '</span><strong>' + amount + '</strong></span>';
    }).join('');
  }

  function panelHtml(found) {
    var slot = found.slot;
    var bank = found.bank;
    var st = statusInfo(slot.status);
    var area = currentArea();
    var facts = [
      fact('Size', sizeLabel(slot)),
      fact('Bank', esc(bank.name) + ' <span class="muted">' + esc(bank.bank_code) + '</span>'),
      fact('Device', esc(bank.device_status || 'ACTIVE'))
    ];
    var prices = priceHtml();
    if (prices) {
      facts.splice(1, 0, fact('Price', '<span class="price-list">' + prices + '</span>'));
    }
    if (slot.status === 'RESERVED' && slot.hold_until) {
      facts.push(fact(slot.mine ? 'Held for you until' : 'Held until', formatTime(slot.hold_until) + countdownHtml(slot.hold_until)));
    }
    if ((slot.status === 'OCCUPIED' || slot.status === 'OVERDUE') && slot.due_at) {
      facts.push(fact('Due', formatTime(slot.due_at) + countdownHtml(slot.due_at)));
    }
    if (slot.occupant && cfg.role !== 'END_USER') {
      facts.push(fact('Used by', esc(slot.occupant)));
    }
    if (slot.alert && inList(ALERT_READERS, cfg.role)) {
      facts.push(fact('Alert', esc(slot.alert.label)));
    }
    return '<div class="panel-head"><div>' +
        '<p class="panel-kicker">' + esc(area ? area.name : '') + '</p>' +
        '<h2 class="panel-title" id="panelTitle" tabindex="-1">Slot ' + esc(slot.slot_code) + '</h2></div>' +
        '<button type="button" class="icon-btn" data-close aria-label="Close details">' + icon('close') + '</button>' +
      '</div>' +
      '<span class="status-pill st-' + esc(slot.status) + '">' + icon(st.icon) + st.label + (slot.mine ? ' · yours' : '') + '</span>' +
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
      el.panel.innerHTML = '<div class="panel-empty"><h2>Select a slot</h2>' +
        '<p>Tap any locker door to see its status and what you can do with it.</p>' + legendHtml() + '</div>';
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
    if (cfg.source === 'mock') {
      if (window.LOCKER_MOCK) {
        onData(window.LOCKER_MOCK.get(state.area, cfg.role));
      }
      return;
    }
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
          toast('Your session has expired. Please log in again.', 'error');
          window.location.reload();
        } else if (first) {
          toast('Could not load the locker map. Retrying every 10 seconds.', 'error');
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

  function onSubmit(e) {
    var form = e.target;
    if (!form.classList.contains('action-form')) {
      return;
    }
    var confirmText = form.getAttribute('data-confirm');
    if (confirmText && !window.confirm(confirmText)) {
      e.preventDefault();
      return;
    }
    if (cfg.source === 'mock') {
      e.preventDefault();
      var fields = {};
      var inputs = form.querySelectorAll('input, select, textarea');
      for (var i = 0; i < inputs.length; i++) {
        fields[inputs[i].name] = inputs[i].value;
      }
      fields.action = fields.action || 'unlock';
      var result = window.LOCKER_MOCK.handle(fields, cfg.role);
      toast(result.message, result.ok ? 'success' : 'error');
      state.panelDirty = false;
      load();
      return;
    }
    // real page: let the browser post the form, the controller redirects back with a flash message
    var button = form.querySelector('[type="submit"]');
    if (button) {
      button.disabled = true;
      button.textContent = 'Sending…';
    }
  }

  function bindEvents() {
    root.addEventListener('click', onClick);
    root.addEventListener('submit', onSubmit);
    el.panel.addEventListener('input', function () {
      state.panelDirty = true;
    });
    el.panel.addEventListener('change', function (e) {
      if (e.target.hasAttribute('data-plan-select')) {
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
  if (cfg.source === 'api') {
    setInterval(function () {
      if (!document.hidden) {
        load();
      }
    }, REFRESH_MS);
  }

  // used by the preview page to switch roles without reloading
  window.LockerMap = {
    setRole: function (role) {
      cfg.role = role;
      root.setAttribute('data-role', role);
      load();
      renderPanel(true);
    },
    reload: load
  };
})();
