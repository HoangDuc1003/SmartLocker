/* Locker map of the staff (ADMIN, OPERATOR, TECHNICIAN, AUDITOR): area menu, locker banks and the slot detail panel.
   Users and visitors get the glass map instead (js/locker-map.js); this page has no booking form.
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
  var STAFF_ROLES = ['ADMIN', 'OPERATOR'];
  var ALERT_READERS = ['ADMIN', 'OPERATOR', 'TECHNICIAN', 'AUDITOR'];

  var STATUS = {
    AVAILABLE: { label: 'Available', icon: 'check' },
    RESERVED: { label: 'Reserved', icon: 'bookmark' },
    OCCUPIED: { label: 'Occupied', icon: 'box' },
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
    unlock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 7.6-1.7"/>',
    box: '<path d="M4 7.5l8-4 8 4v9l-8 4-8-4z"/><path d="M4 7.5l8 4 8-4M12 11.5v9"/>',
    route: '<circle cx="6" cy="18" r="2.2"/><circle cx="18" cy="6" r="2.2"/><path d="M8.2 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.8"/>',
    locate: '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="7.5"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22"/>',
    flag: '<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>',
    chevron: '<path d="M6 9l6 6 6-6"/>',
    fit: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>'
  };

  var cfg = {
    api: root.getAttribute('data-api') || 'api/locker-map',
    role: (root.getAttribute('data-role') || '').toUpperCase(),
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
    popupOpen: false,
    userChoseArea: false,   // the nearest area is picked by itself only until the visitor picks one
    returnFocus: null
  };

  var overlayQuery = window.matchMedia('(max-width: 1799px)')   // same breakpoint as the drawer in css/locker-map-staff.css;
  var el = {};
  var areaMap = null;   // js/area-map.js; null until the skeleton exists

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
    var time = d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
    var today = new Date();
    if (d.toDateString() === today.toDateString()) {
      return time;
    }
    var two = function (n) { return (n < 10 ? '0' : '') + n; };   // 21/10, the same as <ui:dt> prints
    return two(d.getDate()) + '/' + two(d.getMonth() + 1) + ', ' + time;
  }

  // "12:34 left" under an hour, "2 h 05 min left" above, "5:00 late" when the time has passed
  function formatCountdown(iso) {
    var diff = Math.round((parseUtc(iso).getTime() - Date.now()) / 1000);
    var late = diff < 0;
    var s = Math.abs(diff);
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var text = h > 0 ? h + ' h ' + (m < 10 ? '0' : '') + m + ' min'
                     : m + ':' + (sec < 10 ? '0' : '') + sec;
    return { text: late ? text + ' late' : text + ' left', late: late };
  }

  function countdownHtml(iso) {
    var c = formatCountdown(iso);
    return '<span class="countdown' + (c.late ? ' is-late' : '') + '" data-countdown="' + esc(iso) + '">' + esc(c.text) + '</span>';
  }

  function deviceLabel(code) {
    var names = { ACTIVE: 'Active', MAINTENANCE: 'Maintenance', OFFLINE: 'Offline', NONE: 'No device attached' };
    return names[code || 'ACTIVE'] || code;
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
        '<aside class="area-menu" aria-label="Locker areas">' +
          '<h2 class="area-menu__title">Areas</h2>' +
          '<div class="near" data-ref="near"></div>' +
          '<div class="area-list" data-ref="areas"></div>' +
        '</aside>' +
        '<section class="map-main" aria-labelledby="areaTitle">' +
          '<section class="area-map" data-ref="mapCard" aria-labelledby="areaMapTitle">' +
            '<div class="area-map__bar"><h2 id="areaMapTitle" class="area-map__title">Area map</h2>' +
              '<div class="area-map__tools">' +
                '<button type="button" class="btn ghost btn--sm" data-map-fit>' + icon('fit') + 'Show all</button>' +
                '<button type="button" class="btn ghost btn--sm" data-map-me>' + icon('locate') + 'My location</button>' +
                '<button type="button" class="icon-btn" data-map-toggle aria-expanded="true" aria-controls="areaMapBody" aria-label="Collapse the map">' + icon('chevron') + '</button>' +
              '</div></div>' +
            '<div id="areaMapBody" class="area-map__body"><div class="area-map__canvas" data-ref="mapCanvas"></div></div>' +
            '<p class="area-map__empty" data-ref="mapEmpty" hidden>No area has coordinates yet. An administrator enters the latitude and longitude on the Areas page.</p>' +
          '</section>' +
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

  // how full an area is: the colour always comes with a word
  function areaTone(a) {
    if (!a.slot_count) {
      return { key: 'none', label: 'No slots yet' };
    }
    if (!a.available) {
      // every slot behind a silent (or missing) box is not "full": nothing can open it
      return a.offline >= a.slot_count ? { key: 'full', label: 'Offline' } : { key: 'full', label: 'Full' };
    }
    return a.available / a.slot_count < 0.25 ? { key: 'low', label: 'Almost full' } : { key: 'ok', label: 'Plenty free' };
  }

  function ringHtml(a) {
    var pct = a.slot_count ? Math.round(a.available * 100 / a.slot_count) : 0;
    return '<span class="area-item__ring" aria-hidden="true"><svg viewBox="0 0 36 36" focusable="false">' +
      '<circle class="ring__bg" cx="18" cy="18" r="15.9" pathLength="100"/>' +
      '<circle class="ring__fg" cx="18" cy="18" r="15.9" pathLength="100" stroke-dasharray="' + pct + ' 100"/></svg>' +
      '<b>' + esc(a.available) + '</b></span>';
  }

  function renderAreas() {
    var areas = (state.data && state.data.areas) || [];
    if (!areas.length) {
      el.areas.innerHTML = '<p class="muted">No locker areas yet.</p>';
      return;
    }
    var sorted = sortedAreas(areas);
    el.areas.innerHTML = sorted.map(function (a, i) {
      var active = a.area_code === state.area;
      var dist = distanceTo(a);
      var tone = areaTone(a);
      return '<button type="button" class="area-item tone-' + tone.key + (active ? ' is-active' : '') + '" data-area="' + esc(a.area_code) + '"' +
          (active ? ' aria-current="true"' : '') + '>' +
        ringHtml(a) +
        '<span class="area-item__body">' +
          '<span class="area-item__top"><span class="area-item__name">' + esc(a.name) + '</span>' +
            (dist !== null ? '<span class="area-item__dist">' + esc(formatDistance(dist)) + '</span>' : '<span class="area-item__code">' + esc(a.area_code) + '</span>') +
          '</span>' +
          '<span class="area-item__loc">' + esc(a.location) + '</span>' +
          '<span class="area-item__meta"><span class="map-tag map-tag--tone">' + esc(tone.label) + '</span>' +
            '<span>Free ' + esc(a.available) + ' / ' + esc(a.slot_count) + '</span>' +
            (geo.pos && i === 0 && dist !== null ? '<span class="map-tag map-tag--dist">Nearest</span>' : '') +
            (a.alert ? '<span class="map-tag map-tag--alert">' + esc(a.alert) + (a.alert === 1 ? ' alert' : ' alerts') + '</span>' : '') +
          '</span>' +
        '</span>' +
      '</button>';
    }).join('');
    renderMap(areas);
  }

  function renderMap(areas) {
    if (!areaMap) {
      return;
    }
    var placed = areaMap.update(areas, state.area);
    el.mapEmpty.hidden = placed > 0;
    el.mapCanvas.hidden = placed === 0;
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
      html += '<button type="button" class="chip chip--clear" data-filter-clear>Clear filters</button>';
    }
    el.chips.innerHTML = html;
  }

  function deviceTag(bank) {
    if (bank.device_status === 'MAINTENANCE') {
      return '<span class="device-tag device-tag--maintenance"><span class="dot"></span>Device in maintenance</span>';
    }
    if (bank.device_status === 'OFFLINE') {
      return '<span class="device-tag device-tag--offline"><span class="dot"></span>Device offline</span>';
    }
    if (bank.device_status === 'NONE') {
      return '<span class="device-tag device-tag--offline"><span class="dot"></span>No device attached</span>';
    }
    return '<span class="device-tag device-tag--live"><span class="dot"></span>Device online</span>';
  }

  /* ---------- cabinet (spec v3 D9): one block per bank, door height by size S 1 / M 2 / L 3 units ---------- */

  var SIZE_NAMES = { S: 'Small', M: 'Medium', L: 'Large' };

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
    var label = slot.slot_code + ', ' + st.label + ', size ' + size + (slot.locked ? ', locked because overdue' : '') +
      (slot.mine ? ', yours' : '');
    return '<button type="button" class="' + classes + '" data-slot="' + esc(slot.slot_id) + '" aria-label="' + esc(label) + '"' +
        ' aria-pressed="' + (slot.slot_id === state.slotId ? 'true' : 'false') + '" title="' + esc(label) + '">' +
      '<span class="slot__top"><span class="slot__code">' + esc(slot.slot_code) + '</span>' +
        '<span class="slot__size">' + size + '</span></span>' +
      '<span class="slot__icon">' + icon(slot.locked ? 'lock' : st.icon) + '</span>' +
      '<span class="slot__handle" aria-hidden="true"></span>' +
      (slot.mine ? '<span class="slot__you">You</span>' : '') +
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
    return '<div class="cabinet">' +
        '<div class="cabinet__top"><span class="cabinet__plate">' + esc(bank.bank_code) + '</span>' +
          (bank.device_code ? '<span class="cabinet__box" title="Controller box">' + esc(bank.device_code) + '</span>' : '') +
        '</div>' +
        '<div class="cabinet__body">' + cols.map(function (col) {
          return '<div class="cabinet__col">' + col.map(slotHtml).join('') + '</div>';
        }).join('') + '</div>' +
        '<div class="cabinet__base" aria-hidden="true"><span></span><span></span></div>' +
      '</div>';
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
    return free + ' free · ' + used + ' in use' + (locked ? ' · ' + locked + ' locked overdue' : '') +
      (issues ? ' · ' + issues + ' to check' : '');
  }

  function renderBanks() {
    var list = banks();
    if (!state.data) {
      el.banks.innerHTML = '<div class="empty">Loading locker banks…</div>';
      return;
    }
    if (!list.length) {
      el.banks.innerHTML = '<div class="empty">This area has no locker banks yet.</div>';
      return;
    }
    el.banks.innerHTML = list.map(function (bank) {
      return '<article class="bank" aria-label="' + esc(bank.name + ' ' + bank.bank_code) + '">' +
        '<header class="bank__head"><h2 class="bank__name">' + esc(bank.name) +
          (bank.name !== bank.bank_code ? '<span class="bank__code">' + esc(bank.bank_code) + '</span>' : '') +
          '</h2>' + deviceTag(bank) + '</header>' +
        '<div class="bank__scroll">' + cabinetHtml(bank) + '</div>' +
        '<p class="bank__foot">' + bankFoot(bank) + '</p>' +
        reconnectBankForm(bank) +
      '</article>';
    }).join('');
  }

  function renderSync() {
    var text;
    if (state.error) {
      text = 'Connection lost, retrying';
    } else if (!state.loadedAt) {
      text = 'Loading';
    } else {
      var secs = Math.max(0, Math.round((Date.now() - state.loadedAt) / 1000));
      text = secs < 3 ? 'Updated just now' : 'Updated ' + secs + ' s ago';
    }
    el.syncText.textContent = text;
    el.sync.classList.toggle('is-error', !!state.error);
  }

  function legendHtml() {
    return '<ul class="legend">' + STATUS_ORDER.map(function (code) {
      var st = statusInfo(code);
      return '<li><span class="swatch st-' + code + '">' + icon(st.icon) + '</span>' + st.label + '</li>';
    }).join('') +
      '<li><span class="swatch st-OVERDUE">' + icon('lock') + '</span>Locked because overdue (late fee to pay)</li>' +
      '<li><span class="swatch swatch--sizes"><i class="u1"></i><i class="u2"></i><i class="u3"></i></span>Door height by size S, M, L</li>' +
    '</ul>';
  }

  function describe(slot) {
    var mine = slot.mine;
    if (slot.locked) {
      return mine ? 'The booking is overdue, so the slot is locked. The late fee is taken from your wallet; the slot opens again once your balance is 0 VND or more.'
                  : 'The booking in this slot is overdue and the slot is locked.';
    }
    switch (slot.status) {
      case 'AVAILABLE':
        return 'Choose a storage plan and an open method to book this slot.';
      case 'RESERVED':
        return mine ? 'This slot is held for you. When the hold ends the booking starts by itself: early or late, you can use it for the time you paid.'
                    : 'Someone has booked this slot.';
      case 'OCCUPIED':
        return mine ? 'Your things are in this slot.' : 'Someone is using this slot.';
      case 'OVERDUE':
        return mine ? 'Your storage time is over. Extend it or pick up your things before the grace period ends.' : 'The storage time is over.';
      case 'ALERT':
        return 'This slot has an alert; staff are checking it.';
      case 'MAINTENANCE':
        return 'Out of service while a technician checks it.';
      case 'OFFLINE':
        return 'The locker controller is offline, so the status may be out of date.';
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

  function money(n) {
    return (Number(n) || 0).toLocaleString('en-US') + ' VND';
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

  /* size card: picture from the server when the file exists, otherwise a drawn box of that size */
  function sizeArt(code) {
    var k = { S: 0.5, M: 0.75, L: 1 }[code] || 0.5;
    var w = 28 * k, d = 14 * k, h = 30 * k;
    var x0 = 32 - (w + d) / 2, y0 = 56;
    var p = function (x, y) { return (x0 + x).toFixed(1) + ',' + (y0 - y).toFixed(1); };
    // front face, top and side of a box sitting on the floor line
    return '<svg class="size-art" viewBox="0 0 64 64" aria-hidden="true" focusable="false">' +
      '<path class="size-art__floor" d="M4 56.5h56"/>' +
      '<polygon class="size-art__front" points="' + [p(0, 0), p(w, 0), p(w, h), p(0, h)].join(' ') + '"/>' +
      '<polygon class="size-art__side" points="' + [p(w, 0), p(w + d, d * 0.6), p(w + d, h + d * 0.6), p(w, h)].join(' ') + '"/>' +
      '<polygon class="size-art__lid" points="' + [p(0, h), p(w, h), p(w + d, h + d * 0.6), p(d, h + d * 0.6)].join(' ') + '"/>' +
      '<text class="size-art__txt" x="' + (x0 + w / 2).toFixed(1) + '" y="' + (y0 - h / 2 + 3).toFixed(1) + '">' + esc(code) + '</text>' +
    '</svg>';
  }

  function sizeCardHtml(slot) {
    var z = sizeInfo(slot.size) || {};
    var dims = z.size_cm || slot.size_cm;
    var pic = z.img ? '<img src="' + esc(z.img) + '" alt="" width="64" height="64" loading="lazy">' : sizeArt(slot.size);
    var items = z.items && z.items.length ? z.items : null;
    return '<section class="size-card" aria-label="Slot size">' +
      '<div class="size-card__pic">' + pic + '</div>' +
      '<div class="size-card__text">' +
        '<p class="size-card__name">Size ' + esc(slot.size) + ' · ' + esc(SIZE_NAMES[slot.size] || '') +
          (dims ? ' <span class="size-card__dim">' + esc(dims) + ' cm</span>' : '') + '</p>' +
        (items ? '<p class="size-card__fits"><span>Fits:</span> ' + esc(items.join(', ')) + '</p>' : '') +
      '</div>' +
    '</section>';
  }

  function unlockForm(slot, bank) {
    var online = bank.device_status === 'ACTIVE';
    var confirmText = 'Unlock slot ' + slot.slot_code + ' (' + bank.bank_code + ') now? ' +
      'The door opens within about 10 s and the action is written to the log.';
    return formStart(cfg.commandUrl, null, slot, confirmText) +
      '<h3>Remote unlock</h3>' +
      '<label class="field"><span>Reason</span>' +
        '<textarea name="reason" required minlength="5" maxlength="200" placeholder="E.g. Customer forgot the card, ID checked at the front desk"' +
        (online ? '' : ' disabled') + '></textarea></label>' +
      '<button type="submit" class="btn btn--danger btn--block"' + (online ? '' : ' disabled') + '>' + icon('unlock') + 'Unlock now</button>' +
      (online ? '<p class="hint">Only one staff member controls a device at a time.</p>'
              : '<p class="notice notice--warn">The device is not online, so the command cannot be sent.</p>') +
    '</form>';
  }

  function statusForm(slot, bank) {
    var cur = slot.status;
    // OVERDUE / ALERT / OFFLINE are display states with no option: the select starts empty instead of on "Available"
    var known = cur === 'AVAILABLE' || cur === 'MAINTENANCE' || cur === 'OCCUPIED' || cur === 'RESERVED';
    return '<form class="action-form" method="post" action="' + esc(cfg.slotUrl) + '" data-confirm="' +
      esc('Change the status of slot ' + slot.slot_code + '? The action is written to the log.') + '" data-confirm-danger>' +
      hidden('action', 'status') +
      hidden('id', slot.slot_id) +
      hidden('back', 'map') +
      hidden('area', state.area) +
      hidden('slot', slot.slot_id) +
      '<h3>Change slot status</h3>' +
      '<label class="field"><span>Status</span><select name="status" required>' +
        (known ? '' : '<option value="" selected disabled>Choose a new status</option>') +
        '<option value="AVAILABLE"' + (cur === 'AVAILABLE' ? ' selected' : '') + '>Available</option>' +
        '<option value="MAINTENANCE"' + (cur === 'MAINTENANCE' ? ' selected' : '') + '>Maintenance (out of service)</option>' +
        (cur === 'OCCUPIED' ? '<option value="OCCUPIED" selected>Occupied</option>' : '') +
        (cur === 'RESERVED' ? '<option value="RESERVED" selected>Reserved</option>' : '') +
      '</select></label>' +
      '<button type="submit" class="btn btn--block">' + icon('check') + 'Update status</button>' +
    '</form>';
  }

  // Each bank is controlled by one device, so this one action updates every
  // locker of that bank. The server also checks the ADMIN role and audits it.
  function reconnectBankForm(bank) {
    if (cfg.role !== 'ADMIN' || !bank.device_id || bank.device_status === 'ACTIVE') {
      return '';
    }
    // action-form: onSubmit asks through askFirst, which freezes the 10 s refresh while the popup is open
    return '<form class="bank__device-action action-form" method="post" action="' + esc(cfg.alertUrl) + '" ' +
      'data-confirm="Reconnect the whole bank ' + esc(bank.name) + '?">' +
      hidden('action', 'activate_device_from_map') +
      hidden('deviceId', bank.device_id) +
      hidden('area', state.area || '') +
      '<button type="submit" class="btn">' + icon('refresh') + 'Reconnect the whole bank</button>' +
    '</form>';
  }

  // the owner's booking, whatever the slot shows (an OFFLINE box still has the booking): RESERVED until check-in, then ACTIVE
  function bookingPhase(slot) {
    if (!slot.mine || !slot.deposit_id) {
      return null;
    }
    return slot.due_at ? 'ACTIVE' : 'RESERVED';
  }

  function linkButton(url, id, text) {
    var href = url + (url.indexOf('?') === -1 ? '?' : '&') + 'id=' + encodeURIComponent(id);
    return '<a class="btn ghost btn--block" href="' + esc(href) + '">' + esc(text) + '</a>';
  }

  function actionsHtml(slot, bank) {
    var role = cfg.role;
    var parts = [];
    if (slot.alert && inList(ALERT_READERS, role)) {
      parts.push(linkButton(cfg.alertUrl, slot.alert.alert_id, 'View alert #' + slot.alert.alert_id));
    }
    if (slot.ticket_id && inList(ALERT_READERS, role)) {
      parts.push(linkButton(cfg.ticketUrl, slot.ticket_id, 'View maintenance ticket #' + slot.ticket_id));
    }

    if (isStaff()) {
      parts.push(unlockForm(slot, bank));
      parts.push(statusForm(slot, bank));
    } else if (role === 'AUDITOR') {
      parts.push('<p class="notice">View only. Every remote unlock is recorded in the audit log.</p>');
    }
    return parts.join('');
  }

  // prices of this slot's size, before the user pays from the account balance
  function priceHtml(slot) {
    var plans = (state.data && state.data.plans) || [];
    if (!plans.length) {
      return '';
    }
    return plans.map(function (p) {
      var price = Number(p.prices && p.prices[slot.size]) || Number(p.price) || 0;   // one price per size
      return '<span class="price-row"><span>' + esc(p.plan_name) + '</span><strong>' + (price ? esc(money(price)) : 'Free') + '</strong></span>';
    }).join('');
  }

  function panelHtml(found) {
    var slot = found.slot;
    var bank = found.bank;
    var st = statusInfo(slot.status);
    var area = currentArea();
    var z = sizeInfo(slot.size);
    var facts = [
      fact('Locker bank', esc(bank.name) + ' <span class="muted">' + esc(bank.bank_code) + '</span>'),
      fact('Device', esc(deviceLabel(bank.device_status)))
    ];
    var prices = slot.status === 'AVAILABLE' || isStaff() ? priceHtml(slot) : '';
    if (prices) {
      facts.unshift(fact('Price, size ' + esc(slot.size), '<span class="price-list">' + prices + '</span>'));
    }
    if (z && z.overdue_rate && (slot.status === 'AVAILABLE' || slot.mine || isStaff())) {
      facts.push(fact('Late fee', esc(money(z.overdue_rate)) + ' <span class="muted">per hour</span>'));
    }
    var phase = bookingPhase(slot);
    if ((slot.status === 'RESERVED' || phase === 'RESERVED') && slot.hold_until && phase !== 'ACTIVE') {
      facts.push(fact(slot.mine ? 'Held for you until' : 'Held until', formatTime(slot.hold_until) + countdownHtml(slot.hold_until)));
    }
    if ((slot.status === 'OCCUPIED' || slot.status === 'OVERDUE' || phase === 'ACTIVE' || slot.locked) && slot.due_at) {
      facts.push(fact('Due time', formatTime(slot.due_at) + countdownHtml(slot.due_at)));
    }
    if (slot.locked && isStaff()) {
      facts.push(fact('Overdue lock', esc((slot.overdue_hours || 0) + ' h late, ' + money(slot.overdue_fee || 0) + ' charged')));
    }
    if (slot.escalated) {
      facts.push(fact('Escalation', '<span class="text-danger">Escalated to staff (long overdue)</span>'));
    }
    if (slot.occupant && cfg.role !== 'END_USER') {
      facts.push(fact('User', esc(slot.occupant)));
    }
    if (slot.alert && inList(ALERT_READERS, cfg.role)) {
      facts.push(fact('Alert', esc(slot.alert.label)));
    }
    return '<div class="panel-head"><div>' +
        '<p class="panel-kicker">' + esc(area ? area.name : '') + '</p>' +
        '<h2 class="panel-title" id="panelTitle" tabindex="-1">Slot ' + esc(slot.slot_code) + '</h2></div>' +
        '<button type="button" class="icon-btn" data-close aria-label="Close details">' + icon('close') + '</button>' +
      '</div>' +
      '<span class="status-pill st-' + esc(slot.locked ? 'OVERDUE' : slot.status) + '">' + icon(slot.locked ? 'lock' : st.icon) +
        (slot.locked ? 'Overdue lock' : esc(st.label)) + (slot.mine ? ' · yours' : '') + '</span>' +
      '<p class="panel-desc">' + esc(describe(slot)) + '</p>' +
      sizeCardHtml(slot) +
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
      el.panel.innerHTML = '<div class="panel-empty"><h2>Choose a slot</h2>' +
        '<p>Click a slot door to see its status and the actions you can take.</p>' + legendHtml() + '</div>';
      state.panelDirty = false;
      return;
    }
    // keep what the user is typing when a background refresh arrives
    if (state.panelDirty && !force) {
      return;
    }
    el.panel.innerHTML = panelHtml(found);
    state.panelDirty = false;
  }

  function renderAll() {
    renderAreas();
    renderNear();
    renderHead();
    renderChips();
    renderBanks();
    renderPanel(false);
    renderSync();
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
    return m < 1000 ? Math.round(m / 10) * 10 + ' m' : (m / 1000).toFixed(1) + ' km';
  }

  // nearest first; areas without coordinates keep their order at the end
  function sortedAreas(areas) {
    if (!geo.pos) {
      return areas;
    }
    return areas.map(function (a, i) {
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
    var areas = (state.data && state.data.areas) || [];
    if (!areas.some(hasCoords)) {
      el.near.innerHTML = '';
      return;
    }
    var html = '<div class="near__head">' + icon('locate') + '<span>Lockers near you</span></div>';
    var nearest = geo.pos ? sortedAreas(areas)[0] : null;
    if (nearest && distanceTo(nearest) !== null) {
      html += '<p class="near__name"><button type="button" class="link" data-area="' + esc(nearest.area_code) + '">' +
          esc(nearest.name) + '</button> <span class="near__dist">' + esc(formatDistance(distanceTo(nearest))) + '</span></p>' +
        '<p class="near__meta">' + esc(nearest.available + ' / ' + nearest.slot_count + ' slots free') + '</p>' +
        '<a class="btn btn--sm btn--block" href="' + esc(directionsUrl(nearest)) + '" target="_blank" rel="noopener noreferrer">' +
          icon('route') + 'Directions</a>';
    } else if (geo.watchId === null) {
      html += '<p class="near__meta">Let the browser share your location to sort the areas from near to far. The location stays on your device and is never sent.</p>' +
        '<button type="button" class="btn ghost btn--sm btn--block" data-geo-start>' + icon('locate') + 'Find lockers near me</button>';
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
      geo.message = 'This browser does not support location. The area list still works as usual.';
    } else if (window.isSecureContext === false) {
      geo.message = 'Location only works on an HTTPS page. The area list still works as usual.';
    } else if (geo.watchId === null) {
      geo.message = geo.pos ? '' : 'Finding your location…';
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
    // the first fix opens the nearest area, unless the visitor already chose one or the link names one
    if (!geo.picked) {
      geo.picked = true;
      var nearest = state.data && !state.userChoseArea && !readParam('area') ? sortedAreas(state.data.areas)[0] : null;
      if (nearest && distanceTo(nearest) !== null && nearest.area_code !== state.area) {
        selectArea(nearest.area_code, true);
      }
    }
    renderAreas();
    renderNear();
  }

  function onGeoError(err) {
    if (err.code === 1) {
      geoStop();
      geo.wanted = false;
      geo.message = 'Location access is not allowed. Turn on the location permission for this page in your browser to see the nearest lockers.';
    } else if (geo.pos) {
      geo.message = 'Could not update your location; distances use the previous one.';
    } else if (err.code === 3) {
      geo.message = 'Location is taking too long, retrying.';
    } else {
      geo.message = 'Could not find your location. The area list still works as usual.';
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

  // v4: the page asks for the position as soon as it opens (the browser shows its own prompt once);
  // a refusal keeps the list in its normal order and the button "Find lockers near me" asks again
  function geoAutoStart() {
    geoStart();
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
    if (data.guest === true) {
      window.location.reload();   // the session ended: the server draws the visitor's map
      return;
    }
    state.data = normalize(data);
    state.error = null;
    state.loadedAt = Date.now();
    if (data.area && data.area.area_code) {
      state.area = data.area.area_code;
    }
    if (state.popupOpen) {
      return;   // a fetch that started before the popup opened: draw it after the popup (next refresh)
    }
    renderAll();
    if (state.slotId !== null && findSlot(state.slotId)) {
      openOverlay();
    }
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
          toast('Your session has expired. Please sign in again.', 'error');
          window.location.reload();
        } else if (first) {
          toast('Could not load the locker map. Retrying every 10 s.', 'error');
        }
      });
  }

  /* ---------- events ---------- */

  // the list and the pins both end here
  function selectArea(code, byItself) {
    if (!byItself) {
      state.userChoseArea = true;
    }
    if (code === state.area) {
      if (areaMap) {
        areaMap.focus(code);
      }
      return;
    }
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
    if (areaMap) {
      areaMap.focus(code);
    }
    load();
  }

  function toggleMap() {
    var collapsed = !el.mapCard.classList.contains('is-collapsed');
    el.mapCard.classList.toggle('is-collapsed', collapsed);
    var btn = el.mapCard.querySelector('[data-map-toggle]');
    btn.setAttribute('aria-expanded', collapsed ? 'false' : 'true');
    btn.setAttribute('aria-label', collapsed ? 'Expand the map' : 'Collapse the map');
    try {
      window.localStorage.setItem('sl.map.collapsed', collapsed ? '1' : '0');
    } catch (e) {
      // private mode: the choice is just not remembered
    }
    if (!collapsed && areaMap) {
      setTimeout(areaMap.invalidate, 0);
    }
  }

  function onClick(e) {
    var target = e.target.closest('[data-area],[data-slot],[data-filter],[data-filter-clear],[data-close],[data-refresh],[data-geo-start],[data-map-fit],[data-map-me],[data-map-toggle]');
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
    } else if (target.hasAttribute('data-map-toggle')) {
      toggleMap();
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
        state.panelDirty = wasDirty;   // "Back": the panel follows the refresh again
        return;
      }
      if (!form.isConnected) {
        toast('The slot has just changed status. Please try again.', 'error');
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
    if (form.hasAttribute('data-confirm') && form.getAttribute('data-confirmed') !== '1' && window.SmartLocker && window.SmartLocker.confirm) {
      e.preventDefault();
      askFirst(form, {
        title: 'Confirm',
        text: form.getAttribute('data-confirm'),
        okText: 'OK',
        danger: true
      }, e.submitter);
      return;
    }
    // let the browser post the form, the controller redirects back with a flash message
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
      // Esc inside the confirm popup only closes the popup
      if (e.key === 'Escape' && el.panel.classList.contains('is-open') && !document.querySelector('dialog[open]')) {
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
  if (window.AreaMap) {
    areaMap = window.AreaMap.create(el.mapCanvas, { esc: esc, tone: areaTone, onSelect: selectArea, classic: true });
    try {
      if (window.localStorage.getItem('sl.map.collapsed') === '1') {
        toggleMap();
      }
    } catch (e) {
      // no storage: the map starts open
    }
  }
  bindEvents();
  renderAll();
  load();
  geoAutoStart();
  setInterval(tick, 1000);
  setInterval(function () {
    if (!document.hidden && !state.popupOpen) {
      load();
    }
  }, REFRESH_MS);
})();
