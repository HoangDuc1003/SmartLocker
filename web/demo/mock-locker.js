/* Demo data for the locker map, used by the demo pages only: delete the demo folder before you submit.
   get() returns exactly the JSON shape that GET /api/locker-map must return,
   handle() imitates the stored procedure rules when a form is submitted. */
(function () {
  'use strict';

  var MINUTE = 60000;
  var now = Date.now();
  var seed = 20261009;

  function random() {
    seed = (seed * 16807) % 2147483647;
    return (seed - 1) / 2147483646;
  }

  function iso(ms) {
    return new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z');
  }

  function repeat(column, times) {
    var out = [];
    for (var i = 0; i < times; i++) {
      out.push(column);
    }
    return out;
  }

  // Same areas as the Department table of the UserManagement project.
  // Each bank is a list of columns, each column a list of door sizes from top to bottom (L = 2 rows high).
  var LAYOUT = [
    { area_code: 'LIB', name: 'Library', location: 'Library, 1st floor', banks: [
      { bank_code: 'LIB-A', name: 'Bank A', live: true, rows: 2, prefix: 'A', columns: repeat(['S', 'S'], 2) },
      { bank_code: 'LIB-B', name: 'Bank B', rows: 4, prefix: 'B', columns: repeat(['S', 'S', 'S', 'S'], 4) }
    ] },
    { area_code: 'DOMA', name: 'Dormitory A', location: 'Dorm A lobby', banks: [
      { bank_code: 'DOMA-A', name: 'Bank A', rows: 4, prefix: 'A', columns: repeat(['S', 'S', 'S', 'S'], 5) },
      { bank_code: 'DOMA-B', name: 'Bank B', rows: 4, prefix: 'B',
        columns: [['S', 'S', 'L'], ['S', 'S', 'L'], ['L', 'L'], ['L', 'L']] }
    ] },
    { area_code: 'CANT', name: 'Canteen', location: 'Next to the canteen entrance', banks: [
      { bank_code: 'CANT-A', name: 'Bank A', rows: 4, prefix: 'A', columns: repeat(['S', 'S', 'L'], 5) }
    ] },
    { area_code: 'GYM', name: 'Sports Hall', location: 'Sports hall changing room', banks: [
      { bank_code: 'GYM-A', name: 'Bank A', rows: 4, prefix: 'A', columns: repeat(['S', 'S', 'S', 'S'], 4) },
      { bank_code: 'GYM-B', name: 'Bank B', rows: 4, prefix: 'B', columns: repeat(['S', 'S', 'L'], 3) }
    ] }
  ];

  var PLANS = [
    { plan_id: 1, plan_name: '2 hours', duration_min: 120, price: 5000 },
    { plan_id: 3, plan_name: '4 hours', duration_min: 240, price: 9000 },
    { plan_id: 2, plan_name: 'Demo 2 minutes', duration_min: 2, price: 0 }
  ];

  var ALERT_LABELS = ['FORCED_OPEN', 'ITEM_LEFT', 'WRONG_USER', 'SUSPECTED_SPOOF', 'LOST_CARD_USED'];
  var ME = 'student1';
  var ids = { slot: 0, alert: 100, ticket: 40, deposit: 500, command: 10 };

  var areas = [];
  var offlineBackup = null;

  function pickStatus() {
    var r = random();
    if (r < 0.46) { return 'AVAILABLE'; }
    if (r < 0.80) { return 'OCCUPIED'; }
    if (r < 0.87) { return 'RESERVED'; }
    if (r < 0.92) { return 'OVERDUE'; }
    if (r < 0.95) { return 'ALERT'; }
    return 'MAINTENANCE';
  }

  function fillStatus(slot, status, owner) {
    slot.status = status;
    slot.occupant = null;
    slot.owner = null;
    slot.deposit_id = null;
    slot.hold_until = null;
    slot.due_at = null;
    slot.alert = null;
    slot.ticket_id = null;
    if (status === 'RESERVED' || status === 'OCCUPIED' || status === 'OVERDUE' || status === 'ALERT') {
      slot.owner = owner || 'student' + (2 + Math.floor(random() * 60));
      slot.occupant = slot.owner;
      slot.deposit_id = ++ids.deposit;
    }
    if (status === 'RESERVED') {
      slot.hold_until = iso(now + (2 + Math.floor(random() * 12)) * MINUTE);
    } else if (status === 'OCCUPIED') {
      slot.due_at = iso(now + (10 + Math.floor(random() * 170)) * MINUTE);
    } else if (status === 'OVERDUE') {
      slot.due_at = iso(now - (5 + Math.floor(random() * 55)) * MINUTE);
    } else if (status === 'ALERT') {
      slot.alert = { alert_id: ++ids.alert, label: ALERT_LABELS[Math.floor(random() * ALERT_LABELS.length)] };
    } else if (status === 'MAINTENANCE') {
      slot.ticket_id = ++ids.ticket;
    }
  }

  function build() {
    LAYOUT.forEach(function (areaDef) {
      var area = { area_code: areaDef.area_code, name: areaDef.name, location: areaDef.location, banks: [] };
      areaDef.banks.forEach(function (def) {
        var bank = {
          bank_id: area.banks.length + 1 + areas.length * 10,
          bank_code: def.bank_code,
          name: def.name,
          live: !!def.live,
          device_status: def.live ? 'ACTIVE' : null,
          last_seen_sec: def.live ? 3 : null,
          rows: def.rows,
          slots: []
        };
        var n = 0;
        def.columns.forEach(function (column) {
          column.forEach(function (size) {
            n++;
            var slot = {
              slot_id: ++ids.slot,
              slot_code: def.prefix + (n < 10 ? '0' : '') + n,
              size: size,
              size_cm: size === 'L' ? '40x40x90' : '30x30x45',
              mine: false
            };
            fillStatus(slot, def.live ? 'AVAILABLE' : pickStatus());
            bank.slots.push(slot);
          });
        });
        area.banks.push(bank);
      });
      areas.push(area);
    });

    // the real locker: A02 holds the items of student1, A03 is reserved by someone else
    var live = areas[0].banks[0].slots;
    fillStatus(live[1], 'OCCUPIED', ME);
    live[1].due_at = iso(now + 42 * MINUTE);
    fillStatus(live[2], 'RESERVED', 'student7');
    live[2].hold_until = iso(now + 9 * MINUTE);
    // make sure LIB shows one alert and one maintenance slot
    var libB = areas[0].banks[1].slots;
    fillStatus(libB[5], 'ALERT');
    libB[5].alert.label = 'FORCED_OPEN';
    fillStatus(libB[10], 'MAINTENANCE');
  }

  function findArea(code) {
    for (var i = 0; i < areas.length; i++) {
      if (areas[i].area_code === code) {
        return areas[i];
      }
    }
    return areas[0];
  }

  function allSlots() {
    var out = [];
    areas.forEach(function (area) {
      area.banks.forEach(function (bank) {
        bank.slots.forEach(function (slot) {
          out.push({ area: area, bank: bank, slot: slot });
        });
      });
    });
    return out;
  }

  function findSlot(id) {
    var list = allSlots();
    for (var i = 0; i < list.length; i++) {
      if (list[i].slot.slot_id === id) {
        return list[i];
      }
    }
    return null;
  }

  // what the server would send: "mine" for the logged-in user, occupant names only for staff
  function view(slot, role) {
    var copy = {};
    for (var key in slot) {
      if (key !== 'owner') {
        copy[key] = slot[key];
      }
    }
    copy.mine = role === 'END_USER' && slot.owner === ME;
    if (role === 'END_USER') {
      copy.occupant = null;
      copy.alert = null;
      copy.ticket_id = null;
      if (!copy.mine) {
        copy.deposit_id = null;
      }
    }
    return copy;
  }

  function get(areaCode, role) {
    var area = findArea(areaCode);
    var summary = areas.map(function (a) {
      var total = 0, free = 0, alerts = 0, live = false;
      a.banks.forEach(function (b) {
        live = live || b.live;
        b.slots.forEach(function (s) {
          total++;
          if (s.status === 'AVAILABLE') { free++; }
          if (s.status === 'ALERT') { alerts++; }
        });
      });
      return { area_code: a.area_code, name: a.name, location: a.location,
               slot_count: total, available: free, alert: alerts, live: live };
    });
    return {
      generated_at: iso(Date.now()),
      areas: summary,
      area: { area_code: area.area_code, name: area.name, location: area.location },
      plans: PLANS,
      banks: area.banks.map(function (b) {
        return {
          bank_id: b.bank_id, bank_code: b.bank_code, name: b.name, live: b.live,
          device_status: b.device_status,
          last_seen_sec: b.live && b.device_status === 'ACTIVE' ? 1 + Math.floor(Math.random() * 9) : b.last_seen_sec,
          rows: b.rows,
          slots: b.slots.map(function (s) { return view(s, role); })
        };
      })
    };
  }

  function hasBooking() {
    return allSlots().some(function (x) {
      return x.slot.owner === ME && (x.slot.status === 'RESERVED' || x.slot.status === 'OCCUPIED' || x.slot.status === 'OVERDUE');
    });
  }

  // same checks and messages as Deposit_Reserve, RemoteCommand_Create and friends
  function handle(fields, role) {
    var found = findSlot(parseInt(fields.slotId, 10));
    if (!found) {
      return { ok: false, message: 'Slot not found' };
    }
    var slot = found.slot;
    var bank = found.bank;
    switch (fields.action) {
      case 'reserve':
        if (hasBooking()) {
          return { ok: false, message: 'You already have a booking in progress' };
        }
        if (slot.status !== 'AVAILABLE') {
          return { ok: false, message: 'This slot is no longer available' };
        }
        fillStatus(slot, 'RESERVED', ME);
        slot.hold_until = iso(Date.now() + 15 * MINUTE);
        return { ok: true, message: 'Slot ' + slot.slot_code + ' reserved. Swipe your card at the locker within 15 minutes.' };
      case 'cancel':
        if (slot.owner !== ME || slot.status !== 'RESERVED') {
          return { ok: false, message: 'Nothing to cancel' };
        }
        fillStatus(slot, 'AVAILABLE');
        return { ok: true, message: 'Reservation for ' + slot.slot_code + ' cancelled.' };
      case 'extend':
        var minutes = parseInt(fields.minutes, 10) || 60;
        var base = Math.max(Date.now(), new Date(slot.due_at).getTime());
        slot.due_at = iso(base + minutes * MINUTE);
        slot.status = 'OCCUPIED';
        return { ok: true, message: 'Extended by ' + minutes + ' minutes, new due time ' +
          new Date(slot.due_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + '.' };
      case 'unlock':
        if (role !== 'ADMIN' && role !== 'OPERATOR') {
          return { ok: false, message: 'Permission denied' };
        }
        if (bank.device_status !== 'ACTIVE') {
          return { ok: false, message: 'Device is not online, the command cannot be delivered' };
        }
        if (!fields.reason || fields.reason.trim().length < 5) {
          return { ok: false, message: 'A reason of at least 5 characters is required' };
        }
        return { ok: true, message: 'Command #' + (++ids.command) + ' queued, slot ' + slot.slot_code + ' opens within 10 seconds.' };
      default:
        return { ok: false, message: 'Unknown action ' + fields.action };
    }
  }

  // preview toolbar: show what case 1 (device offline) looks like on the live bank
  function setOffline(off) {
    var bank = areas[0].banks[0];
    if (off && !offlineBackup) {
      offlineBackup = bank.slots.map(function (s) { return s.status; });
      bank.device_status = 'OFFLINE';
      bank.last_seen_sec = 95;
      bank.slots.forEach(function (s) { s.status = 'OFFLINE'; });
    } else if (!off && offlineBackup) {
      bank.slots.forEach(function (s, i) { s.status = offlineBackup[i]; });
      bank.device_status = 'ACTIVE';
      offlineBackup = null;
    }
  }

  // the demo gives the slots of 'student1' to whoever is signed in
  function setMe(username) {
    allSlots().forEach(function (x) {
      if (x.slot.owner === ME) { x.slot.owner = username; x.slot.occupant = username; }
    });
    ME = username;
  }

  build();
  window.LOCKER_MOCK = { get: get, handle: handle, setOffline: setOffline, setMe: setMe };
})();
