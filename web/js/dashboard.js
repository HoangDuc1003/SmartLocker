// Operations overview. Polls /api/dashboard (served from the LockerMonitor snapshot) and redraws
// the cards and tables; /api/dashboard?device=ID gives the last sessions of one device for the chart.
// Every value that comes from the server goes through esc() before it is put into HTML.
(function () {
    'use strict';

    var root = document.getElementById('main');
    if (!root || !root.getAttribute('data-api')) return;
    var API = root.getAttribute('data-api');
    var ALERT_URL = root.getAttribute('data-alert-url');

    var interval = 5000;
    var timer = null;
    var inFlight = null;
    var chartRows = [];
    var chartMode = 'a';
    var sessionFilter = 'all';

    function $(id) { return document.getElementById(id); }
    var esc = window.SmartLocker.esc;   // the one HTML escaper, from js/app.js
    function num(n) { return Number(n || 0).toLocaleString('vi-VN'); }
    function setText(id, v) { var el = $(id); if (el && el.textContent !== String(v)) el.textContent = v; }
    function css(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim(); }
    function fmtTime(v) {
        if (!v) return '–';
        // the DB stores UTC; "2026-10-17 00:33:29" has no zone, so it is read as UTC
        var s = String(v).replace(' ', 'T').replace(/(\.\d{3})\d*$/, '$1');
        var d = new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z');
        if (isNaN(d.getTime())) return String(v);
        return d.toLocaleString('vi-VN', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
    }

    var STATUS = {
        ONLINE: ['ok', 'Trực tuyến'], DEGRADED: ['warn', 'Chập chờn'], OFFLINE: ['bad', 'Mất kết nối'],
        ACTIVE: ['ok', 'Hoạt động'], MAINTENANCE: ['warn', 'Bảo trì']
    };
    function tag(code) {
        var s = STATUS[code] || ['', code || '–'];
        return '<span class="tag ' + s[0] + '">' + esc(s[1]) + '</span>';
    }

    function setState(state, text) {
        var el = $('db-state');
        if (!el) return;
        el.setAttribute('data-state', state);
        el.textContent = text;
    }

    // ----- cards -----
    function renderKpis(k) {
        var total = k.totalSlots || 0;
        setText('k-total', num(total));
        setText('k-avail', num(k.availableSlots));
        setText('k-occ', num(k.occupiedSlots));
        setText('k-fault', num(k.maintenanceOrFaultSlots));
        setText('k-over', num(k.overdueSessions));
        setText('k-alerts', num(k.activeAlerts));
        setText('k-offline', num(k.offlineDevices));
        setText('k-rate', total > 0 ? (Math.round(k.occupiedSlots * 1000 / total) / 10).toLocaleString('vi-VN') + '%' : '0%');
        setText('k-audit', k.auditChainValid ? 'Toàn vẹn' : 'Bị sửa đổi');
        $('c-alerts').classList.toggle('warn', k.activeAlerts > 0);
        $('c-offline').classList.toggle('warn', k.offlineDevices > 0);
        $('c-audit').classList.toggle('warn', !k.auditChainValid);
        $('c-audit').classList.toggle('ok', !!k.auditChainValid);
        function pct(v) { return total > 0 ? (v * 100 / total) + '%' : '0%'; }
        $('m-avail').style.width = pct(k.availableSlots);
        $('m-occ').style.width = pct(k.occupiedSlots);
        $('m-fault').style.width = pct(k.maintenanceOrFaultSlots);
    }

    // ----- tables -----
    function renderAreas(rows) {
        var tb = $('db-areas');
        if (!rows || !rows.length) { tb.innerHTML = '<tr><td colspan="5" class="empty">Chưa có khu vực nào.</td></tr>'; return; }
        tb.innerHTML = rows.map(function (r) {
            var pct = r.total > 0 ? Math.round(r.occupied * 100 / r.total) : 0;
            return '<tr><td><b>' + esc(r.areaName) + '</b> <span class="muted">' + esc(r.areaCode) + '</span></td>' +
                '<td class="r num">' + num(r.total) + '</td>' +
                '<td class="r num">' + num(r.occupied) + ' <span class="muted">(' + pct + '%)</span></td>' +
                '<td class="r num">' + num(r.available) + '</td>' +
                '<td class="r num">' + (r.fault > 0 ? '<b class="text-danger">' + num(r.fault) + '</b>' : '0') + '</td></tr>';
        }).join('');
    }

    function renderDevices(list) {
        var tb = $('db-devices');
        if (!list || !list.length) { tb.innerHTML = '<tr><td colspan="4" class="empty">Chưa có thiết bị nào.</td></tr>'; return; }
        var online = list.filter(function (d) { return d.health === 'ONLINE'; }).length;
        setText('db-online', online + '/' + list.length + ' trực tuyến');
        setText('k-online', online + '/' + list.length + ' thiết bị trực tuyến');
        tb.innerHTML = list.map(function (d) {
            var health = d.status === 'MAINTENANCE' ? 'MAINTENANCE' : d.health;
            var seen = d.lastSeenSec === null || d.lastSeenSec === undefined ? 'chưa có'
                : d.lastSeenSec < 120 ? d.lastSeenSec + ' giây trước'
                : d.lastSeenSec < 7200 ? Math.round(d.lastSeenSec / 60) + ' phút trước'
                : Math.round(d.lastSeenSec / 3600) + ' giờ trước';
            return '<tr><td><b>' + esc(d.deviceCode) + '</b></td><td>' + esc(d.location || '–') + '</td>' +
                '<td>' + tag(health) + '</td><td class="r muted">' + esc(seen) + '</td></tr>';
        }).join('');
    }

    function renderAlerts(list) {
        var tb = $('db-alerts');
        if (!list || !list.length) { tb.innerHTML = '<tr><td colspan="4" class="empty">Không có cảnh báo nào.</td></tr>'; return; }
        tb.innerHTML = list.map(function (a) {
            var risk = a.riskScore !== null && a.riskScore !== undefined ? Math.round(a.riskScore * 100) + '%' : '–';
            var cls = a.severity === 'CRITICAL' ? 'bad' : a.severity === 'WARNING' ? 'warn' : '';
            return '<tr><td><a href="' + esc(ALERT_URL) + '?id=' + encodeURIComponent(a.alertId) + '"><b>' + esc(a.label) + '</b></a></td>' +
                '<td>' + esc(a.deviceCode || ('#' + a.deviceId)) + '</td>' +
                '<td class="r"><span class="tag ' + cls + '">' + esc(risk) + '</span></td>' +
                '<td>' + esc(fmtTime(a.createdAt)) + '</td></tr>';
        }).join('');
    }

    function renderSessions(list) {
        var tb = $('db-sessions');
        if (!list || !list.length) return;
        tb.innerHTML = list.map(function (s) {
            var door = Number(s.door_open_sec) || 0;
            var w = Number(s.weight_delta_g) || 0;
            var ok = s.rfid_ok === true || s.rfid_ok === 1;
            return '<tr data-door="' + door + '" data-weight="' + w + '" data-rfid="' + ok + '">' +
                '<td class="num">#' + esc(s.session_id) + '</td>' +
                '<td>Thiết bị #' + esc(s.device_id) + ' · <b>' + esc(s.slot_code || s.slot_id) + '</b></td>' +
                '<td><code>' + esc(s.card_uid || '–') + '</code></td>' +
                '<td class="r num">' + door.toLocaleString('vi-VN', { maximumFractionDigits: 1 }) + ' s</td>' +
                '<td class="r num">' + (w > 0 ? '+' : '') + Math.round(w).toLocaleString('vi-VN') + ' g</td>' +
                '<td><span class="tag ' + (ok ? 'ok' : 'bad') + '">' + (ok ? 'Hợp lệ' : 'Từ chối') + '</span></td>' +
                '<td>' + esc(s.open_source || 'CARD') + '</td>' +
                '<td>' + esc(fmtTime(s.measured_at)) + '</td></tr>';
        }).join('');
        applySessionFilter();
    }

    function applySessionFilter() {
        var rows = $('db-sessions').querySelectorAll('tr[data-door]');
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i];
            var show = true;
            if (sessionFilter === 'door') show = parseFloat(r.getAttribute('data-door')) > 10;
            else if (sessionFilter === 'weight') show = Math.abs(parseFloat(r.getAttribute('data-weight'))) > 10;
            else if (sessionFilter === 'denied') show = r.getAttribute('data-rfid') !== 'true';
            r.hidden = !show;
        }
    }

    // ----- chart: one series, line + points, drawn with the theme colors -----
    function drawChart(hover) {
        var cv = $('db-chart');
        if (!cv) return;
        var box = cv.parentNode;
        var dpr = window.devicePixelRatio || 1;
        var w = box.clientWidth, h = box.clientHeight;
        cv.width = w * dpr; cv.height = h * dpr;
        var ctx = cv.getContext('2d');
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.clearRect(0, 0, w, h);

        var old = box.querySelector('.chart-empty');
        if (!chartRows.length) {
            if (!old) { old = document.createElement('div'); old.className = 'chart-empty'; box.appendChild(old); }
            old.textContent = 'Thiết bị này chưa có phiên mở tủ nào.';
            return;
        }
        if (old) old.parentNode.removeChild(old);

        var padL = 44, padR = 12, padT = 12, padB = 26;
        var vals = chartRows.map(function (r) { return Number(r[chartMode]) || 0; });
        var min = Math.min(0, Math.min.apply(null, vals));
        var max = Math.max.apply(null, vals);
        if (max === min) max = min + 1;
        var x = function (i) { return padL + (vals.length === 1 ? (w - padL - padR) / 2 : i * (w - padL - padR) / (vals.length - 1)); };
        var y = function (v) { return padT + (max - v) * (h - padT - padB) / (max - min); };

        ctx.font = '12px "Segoe UI", system-ui, sans-serif';
        ctx.fillStyle = css('--text-muted');
        ctx.strokeStyle = css('--border');
        ctx.lineWidth = 1;
        ctx.textAlign = 'right';
        for (var g = 0; g <= 4; g++) {
            var gv = min + (max - min) * g / 4;
            var gy = y(gv);
            ctx.beginPath(); ctx.moveTo(padL, gy); ctx.lineTo(w - padR, gy); ctx.stroke();
            ctx.fillText(Math.round(gv).toLocaleString('vi-VN'), padL - 6, gy + 4);
        }
        ctx.textAlign = 'center';
        ctx.fillText('cũ hơn', padL + 20, h - 8);
        ctx.fillText('mới nhất', w - padR - 26, h - 8);

        var color = chartMode === 'a' ? css('--primary') : css('--success');
        ctx.strokeStyle = color; ctx.lineWidth = 2;
        ctx.beginPath();
        vals.forEach(function (v, i) { if (i) ctx.lineTo(x(i), y(v)); else ctx.moveTo(x(i), y(v)); });
        ctx.stroke();
        ctx.fillStyle = color;
        vals.forEach(function (v, i) {
            ctx.beginPath(); ctx.arc(x(i), y(v), i === hover ? 5 : 2.5, 0, Math.PI * 2); ctx.fill();
        });

        var tip = $('db-tip');
        if (hover >= 0 && hover < vals.length) {
            var unit = chartMode === 'a' ? ' giây' : ' g';
            tip.textContent = fmtTime(chartRows[hover].time) + ' · ' +
                vals[hover].toLocaleString('vi-VN', { maximumFractionDigits: 1 }) + unit;
            tip.style.left = x(hover) + 'px';
            tip.style.top = y(vals[hover]) + 'px';
            tip.hidden = false;
        } else {
            tip.hidden = true;
        }
        cv._x = x; cv._n = vals.length;
    }

    function loadChart() {
        var sel = $('db-device');
        if (!sel || !sel.value) { chartRows = []; drawChart(-1); return; }
        fetch(API + '?device=' + encodeURIComponent(sel.value), { credentials: 'same-origin', cache: 'no-store' })
            .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
            .then(function (rows) {
                chartRows = rows || [];
                drawChart(-1);
                setText('db-chart-meta', chartRows.length + ' phiên gần nhất của thiết bị ' + sel.options[sel.selectedIndex].text + '.');
            })
            .catch(function () { setText('db-chart-meta', 'Không tải được dữ liệu cảm biến.'); });
    }

    // ----- polling -----
    function poll() {
        if (inFlight) inFlight.abort();
        var ctrl = window.AbortController ? new AbortController() : null;
        inFlight = ctrl;
        var killer = setTimeout(function () { if (ctrl) ctrl.abort(); }, 8000);
        fetch(API + '?_=' + Date.now(), { credentials: 'same-origin', cache: 'no-store', signal: ctrl ? ctrl.signal : undefined })
            .then(function (r) {
                if (r.status === 401 || r.redirected) { window.location.reload(); return Promise.reject('auth'); }
                return r.ok ? r.json() : Promise.reject(r.status);
            })
            .then(function (d) {
                if (d.kpis) renderKpis(d.kpis);
                if (d.slotBreakdown) renderAreas(d.slotBreakdown);
                if (d.deviceHealth) renderDevices(d.deviceHealth);
                if (d.recentAlerts) renderAlerts(d.recentAlerts);
                if (d.recentSessions) renderSessions(d.recentSessions);
                setState('live', 'Đã kết nối');
                setText('db-time', 'Cập nhật lúc ' + new Date().toLocaleTimeString('vi-VN') + '.');
            })
            .catch(function (err) {
                if (err && err.name === 'AbortError' && inFlight !== ctrl) return;   // replaced by a newer poll
                setState('warn', 'Mất kết nối, đang thử lại');
            })
            .then(function () {
                clearTimeout(killer);
                if (inFlight === ctrl) inFlight = null;
                schedule();
            });
    }

    function schedule() {
        clearTimeout(timer);
        if (interval > 0 && !document.hidden) timer = setTimeout(poll, interval);
    }

    // ----- wiring -----
    $('db-interval').addEventListener('change', function () {
        interval = parseInt(this.value, 10) || 0;
        if (interval === 0) { clearTimeout(timer); setState('idle', 'Đã tạm dừng'); }
        else poll();
    });
    $('db-refresh').addEventListener('click', function () { poll(); loadChart(); });
    var devSel = $('db-device');
    if (devSel) devSel.addEventListener('change', loadChart);

    var modeBtns = document.querySelectorAll('[data-mode]');
    for (var i = 0; i < modeBtns.length; i++) {
        modeBtns[i].addEventListener('click', function () {
            chartMode = this.getAttribute('data-mode');
            for (var j = 0; j < modeBtns.length; j++) modeBtns[j].setAttribute('aria-pressed', modeBtns[j] === this ? 'true' : 'false');
            drawChart(-1);
        });
    }
    var filterBtns = document.querySelectorAll('#db-session-filter [data-filter]');
    for (var k = 0; k < filterBtns.length; k++) {
        filterBtns[k].addEventListener('click', function () {
            sessionFilter = this.getAttribute('data-filter');
            for (var j = 0; j < filterBtns.length; j++) filterBtns[j].setAttribute('aria-pressed', filterBtns[j] === this ? 'true' : 'false');
            applySessionFilter();
        });
    }

    var cv = $('db-chart');
    if (cv) {
        cv.addEventListener('mousemove', function (e) {
            if (!cv._n) return;
            var rect = cv.getBoundingClientRect();
            var mx = e.clientX - rect.left, best = -1, dist = 1e9;
            for (var i = 0; i < cv._n; i++) { var dx = Math.abs(cv._x(i) - mx); if (dx < dist) { dist = dx; best = i; } }
            drawChart(dist < 24 ? best : -1);
        });
        cv.addEventListener('mouseleave', function () { drawChart(-1); });
    }
    window.addEventListener('resize', function () { drawChart(-1); });
    document.addEventListener('sl-theme-change', function () { drawChart(-1); });
    document.addEventListener('visibilitychange', function () { if (!document.hidden && interval > 0) poll(); });

    poll();
    loadChart();
})();
