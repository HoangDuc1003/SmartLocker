/* Dashboard charts, drawn as inline SVG/HTML from the numbers of /api/dashboard (snapshot, every few seconds)
   and /api/dashboard/stats (usage statistics, every minute). No chart library: the page must work offline.
   Colours come from the tokens of css/app.css through classes, never from this file.
   Needs js/app.js first (window.SmartLocker.esc). js/dashboard.js calls DashCharts.snapshot(data). */
(function () {
  'use strict';

  var main = document.getElementById('main');
  if (!main || !main.getAttribute('data-stats-api')) {
    return;
  }
  var STATS_API = main.getAttribute('data-stats-api');
  var STATS_MS = 60000;
  var esc = window.SmartLocker.esc;
  var DAYS = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];
  var DAYS_SHORT = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  var CAT = ['seg-bad', 'seg-warn', 'seg-use', 'seg-ok', 'seg-mute'];   // categorical order for alert types

  var snap = null;
  var stats = null;

  function $(id) { return document.getElementById(id); }
  function num(n) { return Number(n || 0).toLocaleString('vi-VN'); }
  function width(el) { return Math.max(260, Math.floor(el.clientWidth || 0)); }

  function money(n) {
    if (n >= 1000000) { return (n / 1000000).toFixed(1).replace('.', ',').replace(',0', '') + ' tr'; }
    if (n >= 1000) { return Math.round(n / 1000) + 'k'; }
    return String(n);
  }

  // a round axis maximum: 1, 2, 5 times a power of ten
  function niceMax(v) {
    if (v <= 4) { return 4; }
    var p = Math.pow(10, Math.floor(Math.log(v) / Math.LN10));
    var f = v / p;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
  }

  function empty(el, text) {
    el.innerHTML = '<p class="chart-empty">' + esc(text) + '</p>';
  }

  /* ---------- tooltip: one per chart box, driven by data-tip attributes ---------- */

  function bindTip(box) {
    if (box._tip) {
      if (!box.contains(box._tip)) {
        box.appendChild(box._tip);   // a redraw replaced innerHTML; the listeners on the box are still there
      }
      return;
    }
    var tip = document.createElement('div');
    tip.className = 'chart-tip';
    tip.hidden = true;
    tip.setAttribute('role', 'status');
    box.appendChild(tip);
    box._tip = tip;
    function show(target, x, y) {
      tip.textContent = target.getAttribute('data-tip');
      tip.hidden = false;
      var r = box.getBoundingClientRect();
      var left = Math.min(Math.max(x - r.left, 60), r.width - 60);
      tip.style.left = left + 'px';
      tip.style.top = (y - r.top) + 'px';
    }
    box.addEventListener('mousemove', function (e) {
      var t = e.target.closest('[data-tip]');
      if (t) { show(t, e.clientX, e.clientY); } else { tip.hidden = true; }
    });
    box.addEventListener('mouseleave', function () { tip.hidden = true; });
    box.addEventListener('focusin', function (e) {
      var t = e.target.closest('[data-tip]');
      if (t) {
        var b = t.getBoundingClientRect();
        show(t, b.left + b.width / 2, b.top);
      }
    });
    box.addEventListener('focusout', function () { tip.hidden = true; });
  }

  /* ---------- donut ---------- */

  function legendHtml(items) {
    return '<ul class="chart-legend">' + items.map(function (it) {
      return '<li><i class="' + it.cls + '"></i><span>' + esc(it.label) + '</span><b>' + num(it.value) + '</b></li>';
    }).join('') + '</ul>';
  }

  function donut(el, items, big, small, summary) {
    var total = items.reduce(function (s, it) { return s + it.value; }, 0);
    var rings = '';
    if (total > 0) {
      var cum = 0;
      items.forEach(function (it) {
        if (it.value <= 0) { return; }
        var pct = it.value * 100 / total;
        rings += '<circle class="donut__seg ' + it.cls + '" cx="18" cy="18" r="15" pathLength="100" stroke-dasharray="' +
          Math.max(pct - 0.6, 0.4).toFixed(2) + ' 100" stroke-dashoffset="' + (-cum).toFixed(2) +
          '" tabindex="0" data-tip="' + esc(it.label + ': ' + num(it.value) + ' (' + Math.round(pct) + '%)') + '"/>';
        cum += pct;
      });
    }
    el.innerHTML = '<div class="donut"><svg viewBox="0 0 36 36" role="img" aria-label="' + esc(summary) + '">' +
      '<circle class="donut__bg" cx="18" cy="18" r="15"/>' + rings + '</svg>' +
      '<div class="donut__center"><b>' + esc(big) + '</b><span>' + esc(small) + '</span></div></div>' + legendHtml(items);
    bindTip(el);
  }

  /* ---------- snapshot charts ---------- */

  function drawSlots(k) {
    var el = $('ch-slots');
    if (!el || !k) { return; }
    if (!k.totalSlots) { empty(el, 'Chưa có ngăn tủ nào.'); return; }
    var used = Math.round(k.occupiedSlots * 100 / k.totalSlots);
    donut(el, [
      { label: 'Trống', value: k.availableSlots, cls: 'seg-ok' },
      { label: 'Đang dùng', value: k.occupiedSlots, cls: 'seg-use' },
      { label: 'Lỗi hoặc bảo trì', value: k.maintenanceOrFaultSlots, cls: 'seg-bad' }
    ], used + '%', 'đang dùng',
      'Trong ' + k.totalSlots + ' ngăn, ' + k.availableSlots + ' trống, ' + k.occupiedSlots + ' đang dùng, ' + k.maintenanceOrFaultSlots + ' lỗi hoặc bảo trì');
  }

  function drawAreas(rows) {
    var el = $('ch-areas');
    if (!el || !rows) { return; }
    if (!rows.length) { empty(el, 'Chưa có khu vực nào có ngăn tủ.'); return; }
    el.innerHTML = '<ul class="chart-legend chart-legend--row"><li><i class="seg-use"></i><span>Đang dùng</span></li>' +
      '<li><i class="seg-bad"></i><span>Lỗi hoặc bảo trì</span></li><li><i class="seg-ok"></i><span>Trống</span></li></ul>' +
      rows.map(function (r) {
        var t = r.total || 1;
        var tip = r.areaName + ': đang dùng ' + r.occupied + ', lỗi ' + r.fault + ', trống ' + r.available + ' / ' + r.total;
        return '<div class="hbar" data-tip="' + esc(tip) + '" tabindex="0">' +
          '<a class="hbar__name" href="LockerMapController?area=' + encodeURIComponent(r.areaCode) + '">' + esc(r.areaName) + '</a>' +
          '<span class="hbar__track" role="img" aria-label="' + esc(tip) + '">' +
            '<span class="seg-use" style="width:' + (r.occupied * 100 / t) + '%"></span>' +
            '<span class="seg-bad" style="width:' + (r.fault * 100 / t) + '%"></span>' +
            '<span class="seg-ok" style="width:' + (r.available * 100 / t) + '%"></span></span>' +
          '<span class="hbar__val num">' + num(r.available) + ' / ' + num(r.total) + '</span></div>';
      }).join('');
    bindTip(el);
  }

  function drawDevices(list) {
    var el = $('ch-devices');
    if (!el || !list) { return; }
    if (!list.length) { empty(el, 'Chưa có thiết bị nào.'); return; }
    var c = { ONLINE: 0, DEGRADED: 0, OFFLINE: 0 };
    list.forEach(function (d) { c[d.health] = (c[d.health] || 0) + 1; });
    donut(el, [
      { label: 'Trực tuyến', value: c.ONLINE, cls: 'seg-ok' },
      { label: 'Chập chờn', value: c.DEGRADED, cls: 'seg-warn' },
      { label: 'Mất kết nối', value: c.OFFLINE, cls: 'seg-bad' }
    ], c.ONLINE + '/' + list.length, 'trực tuyến',
      c.ONLINE + ' trên ' + list.length + ' thiết bị đang trực tuyến');
  }

  /* ---------- usage charts ---------- */

  function drawAlerts() {
    var el = $('ch-alerts');
    if (!el || !stats) { return; }
    var rows = stats.alertsOpen || [];
    var total = rows.reduce(function (s, r) { return s + r.count; }, 0);
    if (!total) { empty(el, 'Không có cảnh báo nào chưa xử lý.'); return; }
    donut(el, rows.slice(0, 5).map(function (r, i) {
      return { label: r.label, value: r.count, cls: CAT[i % CAT.length] };
    }), String(total), 'chưa xử lý', total + ' cảnh báo chưa xử lý, chia theo loại');
  }

  function drawHourly() {
    var el = $('ch-hourly');
    if (!el || !stats) { return; }
    var today = stats.hourlyToday, yest = stats.hourlyYesterday;
    var total = (stats.bookingsToday || 0) + (stats.bookingsYesterday || 0);
    $('ch-hourly-meta').textContent = 'Hôm nay ' + num(stats.bookingsToday) + ' lượt, hôm qua ' + num(stats.bookingsYesterday) + ' lượt.';
    if (!total) { empty(el, 'Chưa có lượt đặt nào trong hai ngày gần đây.'); return; }
    var nowH = (new Date().getUTCHours() + 7) % 24;   // Vietnam time, the same frame as the server
    var w = width(el), h = 220, pl = 34, pr = 10, pt = 12, pb = 26;
    var max = niceMax(Math.max.apply(null, today.concat(yest)));
    var x = function (i) { return pl + i * (w - pl - pr) / 23; };
    var y = function (v) { return pt + (max - v) * (h - pt - pb) / max; };
    var grid = '';
    for (var g = 0; g <= 4; g++) {
      var gv = max * g / 4;
      grid += '<line class="ax" x1="' + pl + '" x2="' + (w - pr) + '" y1="' + y(gv) + '" y2="' + y(gv) + '"/>' +
        '<text class="axt" x="' + (pl - 6) + '" y="' + (y(gv) + 4) + '" text-anchor="end">' + Math.round(gv) + '</text>';
    }
    for (var i = 0; i < 24; i += 3) {
      grid += '<text class="axt" x="' + x(i) + '" y="' + (h - 8) + '" text-anchor="middle">' + i + 'h</text>';
    }
    var line = function (arr, upto) {
      var pts = [];
      for (var j = 0; j <= upto; j++) { pts.push(x(j).toFixed(1) + ',' + y(arr[j]).toFixed(1)); }
      return pts.join(' ');
    };
    var area = line(today, nowH) + ' ' + x(nowH).toFixed(1) + ',' + y(0) + ' ' + x(0).toFixed(1) + ',' + y(0);
    var hits = '';
    var step = (w - pl - pr) / 23;
    for (var k = 0; k < 24; k++) {
      hits += '<rect class="hit" x="' + (x(k) - step / 2) + '" y="' + pt + '" width="' + step + '" height="' + (h - pt - pb) +
        '" data-tip="' + esc(k + ':00 – hôm nay ' + (k <= nowH ? today[k] : 0) + ' lượt, hôm qua ' + yest[k] + ' lượt') + '"/>';
    }
    var peak = today.indexOf(Math.max.apply(null, today));
    var summary = 'Số lượt đặt theo giờ. Hôm nay ' + stats.bookingsToday + ' lượt' +
      (stats.bookingsToday ? ', cao điểm lúc ' + peak + ' giờ' : '') + '; hôm qua ' + stats.bookingsYesterday + ' lượt.';
    el.innerHTML = '<ul class="chart-legend chart-legend--row"><li><i class="line-use"></i><span>Hôm nay</span></li>' +
      '<li><i class="line-mute"></i><span>Hôm qua</span></li></ul>' +
      '<svg width="' + w + '" height="' + h + '" role="img" aria-label="' + esc(summary) + '">' + grid +
      '<polygon class="area-use" points="' + area + '"/>' +
      '<polyline class="ln ln-mute" points="' + line(yest, 23) + '"/>' +
      '<polyline class="ln ln-use" points="' + line(today, nowH) + '"/>' +
      '<circle class="dot-use" cx="' + x(nowH) + '" cy="' + y(today[nowH]) + '" r="4"/>' + hits + '</svg>';
    bindTip(el);
  }

  function drawHeat() {
    var el = $('ch-heat');
    if (!el || !stats) { return; }
    var heat = stats.heat, max = 0, total = 0;
    heat.forEach(function (row) { row.forEach(function (v) { max = Math.max(max, v); total += v; }); });
    if (!total) { empty(el, 'Chưa có lượt đặt nào trong 4 tuần gần đây.'); return; }
    var w = width(el), pl = 28, top = 18, cell = (w - pl) / 24, ch = Math.min(26, Math.max(18, cell + 4));
    var h = top + 7 * ch + 4;
    var out = '';
    for (var hr = 0; hr < 24; hr += 3) {
      out += '<text class="axt" x="' + (pl + hr * cell + cell / 2) + '" y="11" text-anchor="middle">' + hr + 'h</text>';
    }
    heat.forEach(function (row, d) {
      out += '<text class="axt" x="' + (pl - 6) + '" y="' + (top + d * ch + ch / 2 + 4) + '" text-anchor="end">' + DAYS_SHORT[d] + '</text>';
      row.forEach(function (v, hh) {
        // five steps, so the level can also be read from the tooltip and not only from the shade
        var level = v === 0 ? 0 : Math.min(5, Math.ceil(v * 5 / max));
        out += '<rect class="heat heat-' + level + '" x="' + (pl + hh * cell + 1) + '" y="' + (top + d * ch + 1) + '" width="' +
          Math.max(cell - 2, 2) + '" height="' + (ch - 2) + '" rx="3" data-tip="' +
          esc(DAYS[d] + ' ' + hh + 'h–' + (hh + 1) + 'h: ' + v + ' lượt') + '"/>';
      });
    });
    var best = { v: -1, d: 0, h: 0 };
    heat.forEach(function (row, d) { row.forEach(function (v, hh) { if (v > best.v) { best = { v: v, d: d, h: hh }; } }); });
    el.innerHTML = '<svg width="' + w + '" height="' + h + '" role="img" aria-label="' +
      esc('Lượt đặt theo thứ và giờ trong 4 tuần. Đông nhất: ' + DAYS[best.d] + ' lúc ' + best.h + ' giờ, ' + best.v + ' lượt.') + '">' + out + '</svg>' +
      '<div class="heat-scale" aria-hidden="true"><span>Ít</span><i class="heat heat-1"></i><i class="heat heat-2"></i><i class="heat heat-3"></i><i class="heat heat-4"></i><i class="heat heat-5"></i><span>Nhiều</span></div>';
    bindTip(el);
  }

  function drawRevenue() {
    var card = $('card-revenue');
    var el = $('ch-revenue');
    if (!el || !card) { return; }
    if (!stats || !stats.revenue) { card.hidden = true; return; }   // only ADMIN and OPERATOR get the numbers
    card.hidden = false;
    var rows = stats.revenue;
    var sum = rows.reduce(function (s, r) { return s + r.amount; }, 0);
    $('ch-revenue-meta').textContent = 'Tổng 7 ngày: ' + num(sum) + ' đ';
    if (!sum) { empty(el, 'Chưa có doanh thu trong 7 ngày gần đây.'); return; }
    var w = width(el), h = 200, pl = 8, pr = 8, pt = 22, pb = 26;
    var max = niceMax(Math.max.apply(null, rows.map(function (r) { return r.amount; })));
    var bw = (w - pl - pr) / rows.length;
    var out = '';
    for (var g = 0; g <= 3; g++) {
      var gy = pt + (h - pt - pb) * g / 3;
      out += '<line class="ax" x1="' + pl + '" x2="' + (w - pr) + '" y1="' + gy + '" y2="' + gy + '"/>';
    }
    rows.forEach(function (r, i) {
      var bh = (h - pt - pb) * r.amount / max;
      var bx = pl + i * bw + bw * 0.18, bwid = bw * 0.64, by = h - pb - bh;
      var d = new Date(r.date + 'T00:00:00');
      var label = (d.getDate() < 10 ? '0' : '') + d.getDate() + '/' + (d.getMonth() + 1 < 10 ? '0' : '') + (d.getMonth() + 1);
      out += '<rect class="bar-use" x="' + bx + '" y="' + by + '" width="' + bwid + '" height="' + Math.max(bh, r.amount ? 2 : 0) +
        '" rx="4" tabindex="0" data-tip="' + esc(label + ': ' + num(r.amount) + ' đ') + '"/>' +
        '<text class="axt" x="' + (bx + bwid / 2) + '" y="' + (h - 8) + '" text-anchor="middle">' + label + '</text>' +
        (r.amount ? '<text class="valt" x="' + (bx + bwid / 2) + '" y="' + (by - 5) + '" text-anchor="middle">' + money(r.amount) + '</text>' : '');
    });
    el.innerHTML = '<svg width="' + w + '" height="' + h + '" role="img" aria-label="' +
      esc('Doanh thu gửi đồ 7 ngày gần nhất, tổng ' + num(sum) + ' đồng') + '">' + out + '</svg>';
    bindTip(el);
  }

  function drawUsage() {
    drawAlerts();
    drawHourly();
    drawHeat();
    drawRevenue();
  }

  function loadStats() {
    fetch(STATS_API, { credentials: 'same-origin', cache: 'no-store', headers: { Accept: 'application/json' } })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (d) { stats = d; drawUsage(); })
      .catch(function () {
        ['ch-hourly', 'ch-heat', 'ch-alerts'].forEach(function (id) {
          var el = $(id);
          if (el && !stats) { empty(el, 'Không tải được số liệu thống kê. Sẽ thử lại sau 1 phút.'); }
        });
      });
  }

  window.DashCharts = {
    snapshot: function (d) {
      snap = d;
      drawSlots(d.kpis);
      drawAreas(d.slotBreakdown);
      drawDevices(d.deviceHealth);
    }
  };

  var resizeTimer = null;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(drawUsage, 150);
  });
  loadStats();
  setInterval(function () { if (!document.hidden) { loadStats(); } }, STATS_MS);
})();
