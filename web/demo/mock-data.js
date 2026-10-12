/* Demo data for the user management pages: roles, permissions, areas, users and logs.
   Delete the whole demo folder before you submit. The real pages read the same
   fields from the database through the servlets. */
(function () {
  'use strict';

  var roles = [
    { code: 'ADMIN',      name: 'Administrator',   rank: 1, note: 'Full access to everything' },
    { code: 'OPERATOR',   name: 'Locker Operator', rank: 2, note: 'Manages users, areas and slots, remote unlock' },
    { code: 'TECHNICIAN', name: 'Technician',      rank: 3, note: 'Maintenance, read only elsewhere' },
    { code: 'AUDITOR',    name: 'Auditor',         rank: 4, note: 'Read only, logs and CSV export' },
    { code: 'END_USER',   name: 'Locker User',     rank: 5, note: 'Lowest access, sees the locker map only' }
  ];

  var perms = [
    { code: 'USER_VIEW',     module: 'USER',   name: 'View the user list' },
    { code: 'USER_CREATE',   module: 'USER',   name: 'Create a user' },
    { code: 'USER_UPDATE',   module: 'USER',   name: 'Edit a user' },
    { code: 'USER_DELETE',   module: 'USER',   name: 'Delete a user' },
    { code: 'USER_LOCK',     module: 'USER',   name: 'Lock or unlock an account' },
    { code: 'USER_RESET_PW', module: 'USER',   name: 'Reset a password' },
    { code: 'ROLE_VIEW',     module: 'ROLE',   name: 'View roles' },
    { code: 'ROLE_MANAGE',   module: 'ROLE',   name: 'Assign permissions to roles' },
    { code: 'AREA_VIEW',     module: 'AREA',   name: 'View locker areas' },
    { code: 'AREA_MANAGE',   module: 'AREA',   name: 'Add, edit and delete locker areas' },
    { code: 'MAP_VIEW',      module: 'LOCKER', name: 'View the locker map' },
    { code: 'SLOT_BOOK',     module: 'LOCKER', name: 'Reserve, cancel and extend a slot' },
    { code: 'SLOT_UNLOCK',   module: 'LOCKER', name: 'Remote unlock a slot' },
    { code: 'LOG_VIEW',      module: 'LOG',    name: 'View login and audit logs' },
    { code: 'REPORT_EXPORT', module: 'REPORT', name: 'Export CSV files' },
    { code: 'DASH_VIEW',     module: 'REPORT', name: 'View the dashboard' }
  ];

  function codes() {
    return perms.map(function (p) { return p.code; });
  }

  var rolePerms = {
    ADMIN: codes(),
    OPERATOR: ['USER_VIEW', 'USER_CREATE', 'USER_UPDATE', 'USER_LOCK', 'USER_RESET_PW', 'ROLE_VIEW',
               'AREA_VIEW', 'AREA_MANAGE', 'MAP_VIEW', 'SLOT_UNLOCK', 'LOG_VIEW', 'DASH_VIEW'],
    TECHNICIAN: ['USER_VIEW', 'ROLE_VIEW', 'AREA_VIEW', 'MAP_VIEW', 'DASH_VIEW'],
    AUDITOR: ['USER_VIEW', 'ROLE_VIEW', 'AREA_VIEW', 'MAP_VIEW', 'LOG_VIEW', 'REPORT_EXPORT', 'DASH_VIEW'],
    END_USER: ['MAP_VIEW', 'SLOT_BOOK']
  };

  // slots = number of locker doors in the area, same figures as the locker map
  var areas = [
    { code: 'LIB',  name: 'Library Locker Bank',  note: 'Library, 1st floor',               slots: 20, active: true },
    { code: 'DOMA', name: 'Dormitory A Lockers',  note: 'Dorm A lobby',                      slots: 30, active: true },
    { code: 'CANT', name: 'Canteen Lockers',      note: 'Next to the canteen entrance',      slots: 15, active: true },
    { code: 'GYM',  name: 'Sports Hall Lockers',  note: 'Sports hall changing room',         slots: 25, active: true },
    { code: 'OPS',  name: 'Operations Office',    note: 'Staff office, no locker slots',     slots: 0,  active: true }
  ];

  var users = [
    ['admin',     'Administrator',     'ADMIN',      'OPS',  0],
    ['operator1', 'Tran Thi Hoa',      'OPERATOR',   'OPS',  0],
    ['operator2', 'Le Van Minh',       'OPERATOR',   'OPS',  0],
    ['tech1',     'Pham Quoc Bao',     'TECHNICIAN', 'OPS',  0],
    ['tech2',     'Vo Thi Lan',        'TECHNICIAN', 'OPS',  0],
    ['auditor1',  'Nguyen Thanh Tung', 'AUDITOR',    'OPS',  0],
    ['auditor2',  'Do Thi Mai',        'AUDITOR',    'OPS',  0],
    ['student1',  'Nguyen Van An',     'END_USER',   'LIB',  0],
    ['student2',  'Tran Minh Chau',    'END_USER',   'DOMA', 0],
    ['student3',  'Le Hoang Nam',      'END_USER',   'CANT', 0],
    ['student4',  'Pham Thu Ha',       'END_USER',   'GYM',  0],
    ['student5',  'Dang Quoc Huy',     'END_USER',   'LIB',  0],
    ['student6',  'Ngo Bao Tram',      'END_USER',   'DOMA', 0],
    ['student7',  'Huynh Gia Bao',     'END_USER',   'LIB',  0],
    ['student8',  'Vu Ngoc Anh',       'END_USER',   'GYM',  0],
    ['locked1',   'Bui Van Khoa',      'END_USER',   'DOMA', 1]
  ].map(function (r, i) {
    return {
      id: i + 1, username: r[0], fullName: r[1], role: r[2], area: r[3], locked: !!r[4],
      email: r[0] + '@smartlocker.edu.vn',
      phone: i % 3 === 0 ? '' : '09' + String(10000000 + i * 1234567).slice(0, 8),
      balance: 0
    };
  });

  // ---- logs: built from fixed rows so every visit shows the same history ----
  function ago(min) {
    return new Date(Date.now() - min * 60000);
  }

  var logins = [];
  var names = ['student1', 'operator1', 'admin', 'student2', 'tech1', 'student3', 'auditor1', 'student4',
               'operator2', 'student5', 'student6', 'admin'];
  for (var i = 0; i < 28; i++) {
    logins.push({ id: 28 - i, at: ago(7 + i * 41), username: names[i % names.length], ok: true,
                  ip: '192.168.1.' + (20 + (i * 7) % 60) });
  }
  [[3, 'admn'], [9, 'locked1'], [10, 'locked1'], [17, 'student2'], [22, 'root']].forEach(function (f) {
    logins[f[0]].username = f[1];
    logins[f[0]].ok = false;
  });

  var audits = [
    [5,    'operator1', 'REMOTE_UNLOCK', 'LOCKERSLOT', 2,  'Student forgot card, ID checked at the desk'],
    [31,   'system',    'MARK_OFFLINE',  'DEVICE',      1,  'No heartbeat for 60 s'],
    [38,   'system',    'BACK_ONLINE',   'DEVICE',      1,  ''],
    [64,   'student1',  'RESERVE',       'DEPOSIT',     12, 'Slot A03, 2 hours plan'],
    [80,   'student3',  'REPORT_LOST',   'USERCARD',    4,  'Card 04A1B2C3 blocked'],
    [96,   'system',    'NO_SHOW',       'DEPOSIT',     9,  'Reservation expired after 15 minutes'],
    [140,  'system',    'OPEN_TICKET',   'MAINTENANCE', 7,  'SENSOR_FAULT: weight outside the valid range'],
    [205,  'admin',     'UPDATE',        'ROLE',        2,  'Permissions of OPERATOR changed'],
    [260,  'operator1', 'LOCK',          'AppUser',     16, 'locked1 locked'],
    [310,  'operator1', 'RESET',         'AppUser',     9,  'Password reset for student2'],
    [420,  'operator2', 'CREATE',        'AppUser',     15, 'student8 created'],
    [600,  'admin',     'DELETE',        'AppUser',     14, 'old_account removed'],
    [720,  'operator1', 'UPDATE',        'LockerArea',  3,  'CANT note changed'],
    [900,  'admin',     'CREATE',        'AppUser',     6,  'auditor2 created'],
    [1200, 'operator2', 'REMOTE_UNLOCK', 'LOCKERSLOT',  4,  'Door jammed, user waiting'],
    [1500, 'student2',  'RESERVE',       'DEPOSIT',     8,  'Slot B05, 4 hours plan'],
    [1900, 'system',    'NO_SHOW',       'DEPOSIT',     6,  'Reservation expired after 15 minutes'],
    [2500, 'admin',     'UPDATE',        'AppUser',     3,  'operator2 changed to area OPS'],
    [3100, 'tech1',     'UPDATE',        'MAINTENANCE', 5,  'Ticket closed after recalibration'],
    [4200, 'admin',     'CREATE',        'LockerArea',  5,  'OPS created']
  ].map(function (r, k, all) {
    return { id: all.length - k, at: ago(r[0]), actor: r[1], action: r[2], table: r[3], target: r[4], detail: r[5] };
  });

  window.DEMO_DATA = {
    roles: roles, perms: perms, rolePerms: rolePerms, areas: areas, users: users,
    logins: logins, audits: audits
  };
})();
