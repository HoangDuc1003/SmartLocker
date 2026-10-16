<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="dashboard"/>
<%--
  dashboard.jsp — Enterprise IoT Control Center
  DashboardController puts nothing extra here; all live data is fetched via
  /api/dashboard every 2-5 seconds by the Vanilla JS engine below.
  The page shell (nav, wrapper) renders server-side; KPI cards and feeds are
  updated in-place without any full-page reload.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="theme-color" content="#1a2540">
  <title>Dashboard — Smart Locker</title>
  <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
  <style>
    /* ─── Dashboard-specific tokens ─────────────────────────────────────── */
    :root {
      --db-bg:          #f0f2f7;
      --db-card:        #ffffff;
      --db-card-border: #dde1eb;
      --db-navy:        #1a2540;
      --db-navy-soft:   #2b3a55;
      --db-green:       #12873a;
      --db-green-soft:  #e6f7ee;
      --db-amber:       #d97706;
      --db-amber-soft:  #fef3c7;
      --db-red:         #c0392b;
      --db-red-soft:    #fde8e8;
      --db-blue:        #1d6fa4;
      --db-blue-soft:   #e8f4fd;
      --db-gray-soft:   #f5f6fa;
      --db-radius:      10px;
      --db-shadow:      0 2px 8px rgba(26,37,64,.08), 0 0 0 1px rgba(26,37,64,.05);
      --db-shadow-lg:   0 8px 24px rgba(26,37,64,.14);
      --db-transition:  0.22s ease;
    }

    body { background: var(--db-bg); }

    /* ─── Status bar ─────────────────────────────────────────────────────── */
    .db-statusbar {
      display: flex; align-items: center; gap: 16px; flex-wrap: wrap;
      padding: 8px 20px; background: var(--db-navy); color: #cdd5e8;
      font-size: 12px; border-bottom: 1px solid rgba(255,255,255,.07);
    }
    .db-live-dot {
      display: inline-block !important;
      width: 8px !important;
      height: 8px !important;
      min-width: 8px !important;
      min-height: 8px !important;
      max-width: 8px !important;
      max-height: 8px !important;
      padding: 0 !important;
      margin: 0 !important;
      border: none !important;
      border-radius: 50% !important;
      flex-shrink: 0 !important;
      background: #22c55e;
      box-shadow: 0 0 0 0 rgba(34,197,94,.6);
      animation: pulse-green 2s infinite;
      vertical-align: middle;
      line-height: 1 !important;
    }
    .db-live-dot.db-live-dot--warn  {
      background: #f59e0b !important;
      box-shadow: 0 0 0 0 rgba(245,158,11,.6) !important;
      animation: pulse-amber 1.5s infinite !important;
    }
    .db-live-dot.db-live-dot--error {
      background: #ef4444 !important;
      box-shadow: 0 0 0 0 rgba(239,68,68,.6) !important;
      animation: pulse-red 1s infinite !important;
    }
    @keyframes pulse-green { 70% { box-shadow: 0 0 0 8px rgba(34,197,94,0);  } 100% { box-shadow: 0 0 0 0 rgba(34,197,94,0);  } }
    @keyframes pulse-amber { 70% { box-shadow: 0 0 0 8px rgba(245,158,11,0); } 100% { box-shadow: 0 0 0 0 rgba(245,158,11,0); } }
    @keyframes pulse-red   { 70% { box-shadow: 0 0 0 8px rgba(239,68,68,0);  } 100% { box-shadow: 0 0 0 0 rgba(239,68,68,0);  } }

    #db-connection-label { font-weight: 600; }
    #db-server-time { margin-left: auto; }
    .db-statusbar-sep { opacity: .3; }

    .db-refresh-ctl { display: flex; gap: 6px; align-items: center; margin-left: auto; }
    .db-refresh-ctl select, .db-refresh-ctl button {
      font-size: 11px; padding: 3px 8px; border-radius: 4px; border: 1px solid rgba(255,255,255,.25);
      background: rgba(255,255,255,.1); color: #dfe6f2; cursor: pointer; font-family: inherit;
    }
    .db-refresh-ctl button:hover { background: rgba(255,255,255,.2); }

    /* ─── Wrap ───────────────────────────────────────────────────────────── */
    .db-wrap { max-width: 1400px; margin: 20px auto; padding: 0 18px; }

    /* ─── KPI bento grid ─────────────────────────────────────────────────── */
    .db-kpi-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(190px, 1fr));
      gap: 14px; margin-bottom: 20px;
    }
    .db-kpi {
      background: var(--db-card); border: 1px solid var(--db-card-border);
      border-radius: var(--db-radius); padding: 16px 18px;
      box-shadow: var(--db-shadow); position: relative; overflow: hidden;
      transition: box-shadow var(--db-transition);
    }
    .db-kpi:hover { box-shadow: var(--db-shadow-lg); }
    .db-kpi__icon {
      width: 36px; height: 36px; border-radius: 8px; display: flex;
      align-items: center; justify-content: center; margin-bottom: 12px;
    }
    .db-kpi__icon svg { width: 20px; height: 20px; fill: none; stroke: currentColor;
                        stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
    .db-kpi__num {
      font-size: 32px; font-weight: 700; line-height: 1; letter-spacing: -1px;
      transition: color var(--db-transition);
    }
    .db-kpi__label { font-size: 12px; color: #667; margin-top: 4px; font-weight: 500; }
    .db-kpi__bar-wrap { height: 4px; background: #eceef2; border-radius: 2px; margin-top: 10px; overflow: hidden; }
    .db-kpi__bar { height: 100%; border-radius: 2px; transition: width .5s ease; }
    .db-kpi__badge {
      position: absolute; top: 12px; right: 12px;
      font-size: 10px; font-weight: 700; padding: 2px 7px; border-radius: 20px;
      text-transform: uppercase; letter-spacing: .5px;
    }

    /* Colour variants */
    .kpi--green  .db-kpi__icon { background: var(--db-green-soft); color: var(--db-green); }
    .kpi--green  .db-kpi__bar  { background: var(--db-green); }
    .kpi--blue   .db-kpi__icon { background: var(--db-blue-soft);  color: var(--db-blue); }
    .kpi--blue   .db-kpi__bar  { background: var(--db-blue); }
    .kpi--amber  .db-kpi__icon { background: var(--db-amber-soft); color: var(--db-amber); }
    .kpi--amber  .db-kpi__bar  { background: var(--db-amber); }
    .kpi--red    .db-kpi__icon { background: var(--db-red-soft);   color: var(--db-red); }
    .kpi--red    .db-kpi__bar  { background: var(--db-red); }
    .kpi--navy   .db-kpi__icon { background: #e6ebf3;              color: var(--db-navy-soft); }
    .kpi--navy   .db-kpi__bar  { background: var(--db-navy-soft); }

    .badge--warn { background: var(--db-amber-soft); color: var(--db-amber); }
    .badge--crit { background: var(--db-red-soft);   color: var(--db-red);   }
    .badge--ok   { background: var(--db-green-soft); color: var(--db-green); }

    /* Number flash on change */
    @keyframes num-flash { 0%,100%{} 30%{background:rgba(255,220,50,.35);border-radius:4px;} }
    .num-changed { animation: num-flash .5s ease-out; }

    /* ─── Split-view centre ──────────────────────────────────────────────── */
    .db-center {
      display: grid;
      grid-template-columns: 7fr 5fr;
      gap: 16px;
      align-items: start;
    }
    @media (max-width: 960px) { .db-center { grid-template-columns: 1fr; } }

    /* ─── Slot matrix panel ──────────────────────────────────────────────── */
    .db-panel {
      background: var(--db-card); border: 1px solid var(--db-card-border);
      border-radius: var(--db-radius); box-shadow: var(--db-shadow);
    }
    .db-panel__head {
      display: flex; align-items: center; gap: 10px; padding: 14px 18px;
      border-bottom: 1px solid var(--db-card-border);
    }
    .db-panel__head h3 { margin: 0; font-size: 14px; font-weight: 700; }
    .db-panel__head .db-panel__meta { font-size: 11px; color: #888; margin-left: auto; }
    .db-panel__body { padding: 16px 18px; }

    /* Area breakdown table */
    .db-area-table { width: 100%; border-collapse: collapse; font-size: 13px; }
    .db-area-table th { font-weight: 600; color: #667; font-size: 11px; text-transform: uppercase;
                        letter-spacing: .5px; padding: 0 6px 8px; text-align: left; }
    .db-area-table td { padding: 7px 6px; border-top: 1px solid #f0f2f5; vertical-align: middle; }
    .db-area-table .occupancy-bar-wrap { background: #eceef2; border-radius: 3px; height: 6px; width: 80px; overflow: hidden; display: inline-block; vertical-align: middle; margin-left: 6px; }
    .db-area-table .occupancy-bar      { height: 100%; border-radius: 3px; background: var(--db-blue); transition: width .5s; }
    .db-occ-pct    { font-weight: 600; font-size: 11px; color: var(--db-blue); min-width: 32px; display: inline-block; }

    /* Slot legend */
    .db-legend { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 12px; }
    .db-legend-item { display: flex; align-items: center; gap: 5px; font-size: 11px; color: #555; }
    .db-dot { width: 10px; height: 10px; border-radius: 3px; flex-shrink: 0; }
    .db-dot--avail  { background: #22c55e; }
    .db-dot--occ    { background: #3b82f6; }
    .db-dot--rsv    { background: #f59e0b; }
    .db-dot--over   { background: #f97316; }
    .db-dot--fault  { background: #ef4444; }
    .db-dot--maint  { background: #94a3b8; }

    /* Device health list */
    .db-device-list { display: flex; flex-direction: column; gap: 8px; }
    .db-device-row  {
      display: flex; align-items: center; gap: 10px; padding: 10px 12px;
      background: var(--db-gray-soft); border-radius: 7px; font-size: 12px;
    }
    .db-device-row__code { font-weight: 700; font-size: 13px; min-width: 60px; }
    .db-device-row__loc  { color: #667; flex: 1; }
    .db-hbadge {
      padding: 2px 9px; border-radius: 20px; font-size: 11px; font-weight: 700;
      text-transform: uppercase; letter-spacing: .4px;
    }
    .h-online  { background: var(--db-green-soft);  color: var(--db-green); }
    .h-degraded{ background: var(--db-amber-soft);  color: var(--db-amber); }
    .h-offline { background: var(--db-red-soft);    color: var(--db-red);   }
    .db-device-row__hb { font-size: 11px; color: #999; min-width: 56px; text-align: right; }

    /* ─── Alert feed ─────────────────────────────────────────────────────── */
    .db-alert-feed { display: flex; flex-direction: column; gap: 6px; max-height: 340px; overflow-y: auto; }
    .db-alert-item {
      display: flex; gap: 10px; padding: 10px 12px; border-radius: 7px;
      font-size: 12px; border-left: 3px solid transparent; transition: background .2s;
    }
    .db-alert-item:hover { background: rgba(0,0,0,.03); }
    .db-alert-item.sev-CRITICAL { border-color: var(--db-red);   background: #fff5f5; }
    .db-alert-item.sev-WARNING  { border-color: var(--db-amber); background: #fffbf0; }
    .db-alert-item.sev-INFO     { border-color: var(--db-blue);  background: var(--db-blue-soft); }
    .db-alert-item__icon { font-size: 16px; flex-shrink: 0; margin-top: 1px; }
    .db-alert-item__body { flex: 1; min-width: 0; }
    .db-alert-item__label { font-weight: 700; color: #1a2540; }
    .db-alert-item__sub   { color: #888; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .db-alert-item__risk  { font-size: 11px; font-weight: 600; min-width: 36px; text-align: right; padding-top: 2px; }

    /* Audit integrity badge */
    .db-audit-badge {
      display: flex; align-items: center; gap: 8px; padding: 10px 14px;
      border-radius: 7px; font-size: 12px; font-weight: 600; margin-top: 10px;
    }
    .db-audit-badge.ok   { background: var(--db-green-soft); color: var(--db-green); }
    .db-audit-badge.bad  { background: var(--db-red-soft);   color: var(--db-red);   }

    /* ─── Empty / loading states ─────────────────────────────────────────── */
    .db-empty { text-align: center; color: #aaa; font-size: 13px; padding: 24px 0; }
    .db-spinner {
      width: 20px; height: 20px; border: 2px solid #dde1eb;
      border-top-color: var(--db-blue); border-radius: 50%;
      animation: spin .7s linear infinite; display: inline-block;
    }
    @keyframes spin { to { transform: rotate(360deg); } }

    /* ─── Slot modal / tooltip ───────────────────────────────────────────── */
    .db-modal-backdrop {
      display: none; position: fixed; inset: 0; background: rgba(0,0,0,.45);
      z-index: 100; align-items: center; justify-content: center;
    }
    .db-modal-backdrop.open { display: flex; }
    .db-modal {
      background: #fff; border-radius: var(--db-radius); padding: 24px 28px;
      max-width: 380px; width: 90%; box-shadow: var(--db-shadow-lg);
      animation: modal-in .18s ease-out;
    }
    @keyframes modal-in { from { opacity:0; transform: scale(.96) translateY(-6px); } }
    .db-modal h4 { margin: 0 0 14px; font-size: 16px; }
    .db-modal-close {
      float: right; background: none; border: none; font-size: 20px;
      cursor: pointer; color: #888; margin-top: -4px;
    }
    .db-modal dl { display: grid; grid-template-columns: auto 1fr; gap: 6px 14px;
                   font-size: 13px; margin: 0; }
    .db-modal dt { font-weight: 600; color: #667; }
    .db-modal dd { margin: 0; word-break: break-all; }
  </style>
</head>
<body>
<%@ include file="common/nav.jspf" %>

<%-- ── Live status bar ────────────────────────────────────────────────── --%>
<div class="db-statusbar">
  <span class="db-live-dot" id="db-dot"></span>
  <span id="db-connection-label">LIVE</span>
  <span class="db-statusbar-sep">|</span>
  <span id="db-server-time">Connected</span>
  <span class="db-statusbar-sep">|</span>
  <span id="db-poll-count" style="opacity:.6">0 polls</span>
  <div class="db-refresh-ctl">
    <label style="opacity:.8">Interval:</label>
    <select id="db-interval-sel">
      <option value="2000">2 s</option>
      <option value="5000" selected>5 s</option>
      <option value="10000">10 s</option>
      <option value="0">Pause</option>
    </select>
    <button onclick="scheduleNext(0)">⟳ Now</button>
  </div>
</div>

<%-- ── Main content wrap ──────────────────────────────────────────────── --%>
<div class="db-wrap">

  <%-- KPI bento grid --%>
  <div class="db-kpi-grid">

    <div class="db-kpi kpi--green" id="kpi-avail">
      <div class="db-kpi__icon">
        <svg viewBox="0 0 24 24"><path d="M20 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2z"/><path d="M16 3h-8l-2 4h12l-2-4z"/></svg>
      </div>
      <div class="db-kpi__num" id="kv-avail">${not empty kpis ? kpis.availableSlots : (not empty counts.free ? counts.free : 0)}</div>
      <div class="db-kpi__label">Available slots</div>
      <div class="db-kpi__bar-wrap"><div class="db-kpi__bar" id="kb-avail" style="width:${not empty kpis and kpis.totalSlots > 0 ? (kpis.availableSlots * 100 / kpis.totalSlots) : 0}%"></div></div>
    </div>

    <div class="db-kpi kpi--blue" id="kpi-occ">
      <div class="db-kpi__icon">
        <svg viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
      </div>
      <div class="db-kpi__num" id="kv-occ">${not empty kpis ? kpis.occupiedSlots : (not empty counts.inUse ? counts.inUse : 0)}</div>
      <div class="db-kpi__label">Occupied slots</div>
      <div class="db-kpi__bar-wrap"><div class="db-kpi__bar" id="kb-occ" style="width:${not empty kpis and kpis.totalSlots > 0 ? (kpis.occupiedSlots * 100 / kpis.totalSlots) : 0}%"></div></div>
    </div>

    <div class="db-kpi ${(not empty kpis and kpis.overdueSessions > 0) or (not empty counts and counts.overdue > 0) ? 'kpi--red' : 'kpi--amber'}" id="kpi-over">
      <div class="db-kpi__icon">
        <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
      </div>
      <div class="db-kpi__num" id="kv-over">${not empty kpis ? kpis.overdueSessions : (not empty counts.overdue ? counts.overdue : 0)}</div>
      <div class="db-kpi__label">Overdue sessions</div>
      <div class="db-kpi__bar-wrap"><div class="db-kpi__bar" id="kb-over" style="width:${not empty kpis and kpis.totalSlots > 0 ? (kpis.overdueSessions * 100 / kpis.totalSlots) : 0}%"></div></div>
    </div>

    <div class="db-kpi kpi--red" id="kpi-alert">
      <div class="db-kpi__icon">
        <svg viewBox="0 0 24 24"><polygon points="10.29 3.86 1.82 18 22.18 18 13.71 3.86 10.29 3.86"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
      </div>
      <div class="db-kpi__num" id="kv-alert">${not empty kpis ? kpis.activeAlerts : (not empty counts.openAlerts ? counts.openAlerts : 0)}</div>
      <div class="db-kpi__label">Active alerts</div>
      <c:if test="${(not empty kpis and kpis.activeAlerts > 0) or (not empty counts and counts.openAlerts > 0)}">
        <span class="db-kpi__badge badge--crit">${not empty kpis ? kpis.activeAlerts : counts.openAlerts} OPEN</span>
      </c:if>
    </div>

    <div class="db-kpi kpi--navy" id="kpi-device">
      <div class="db-kpi__icon">
        <svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
      </div>
      <div class="db-kpi__num" id="kv-device">${not empty kpis ? kpis.offlineDevices : (not empty counts.offlineDevices ? counts.offlineDevices : 0)}</div>
      <div class="db-kpi__label">Devices offline</div>
    </div>

  </div><%-- /kpi-grid --%>

  <%-- Split-view centre --%>
  <div class="db-center">

    <%-- Left col: slot breakdown + device health --%>
    <div style="display:flex;flex-direction:column;gap:16px;">

      <%-- Area slot breakdown --%>
      <div class="db-panel">
        <div class="db-panel__head">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#2b3a55" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
          <h3>Slot breakdown by area</h3>
          <span class="db-panel__meta" id="db-total-label">— total</span>
        </div>
        <div class="db-panel__body">
          <div class="db-legend">
            <span class="db-legend-item"><span class="db-dot db-dot--avail"></span>Available</span>
            <span class="db-legend-item"><span class="db-dot db-dot--occ"></span>Occupied</span>
            <span class="db-legend-item"><span class="db-dot db-dot--over"></span>Overdue</span>
            <span class="db-legend-item"><span class="db-dot db-dot--fault"></span>Fault/Maint.</span>
          </div>
          <table class="db-area-table">
            <thead><tr>
              <th>Area</th><th>Total</th><th style="text-align:right">Occupancy</th><th style="text-align:right">Fault</th>
            </tr></thead>
            <tbody id="db-area-tbody">
              <tr><td colspan="4" class="db-empty"><span class="db-spinner"></span></td></tr>
            </tbody>
          </table>
        </div>
      </div>

      <%-- Device health --%>
      <div class="db-panel">
        <div class="db-panel__head">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#2b3a55" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
          <h3>Device health</h3>
          <span class="db-panel__meta" id="db-online-label">—</span>
        </div>
        <div class="db-panel__body">
          <div class="db-device-list" id="db-device-list">
            <div class="db-empty"><span class="db-spinner"></span></div>
          </div>
        </div>
      </div>

    </div><%-- /left col --%>

    <%-- Right col: alert feed + audit integrity --%>
    <div style="display:flex;flex-direction:column;gap:16px;">

      <div class="db-panel">
        <div class="db-panel__head">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#c0392b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="10.29 3.86 1.82 18 22.18 18 13.71 3.86 10.29 3.86"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
          <h3>Security alert feed</h3>
          <span class="db-panel__meta">Live · last 10</span>
        </div>
        <div class="db-panel__body">
          <div class="db-alert-feed" id="db-alert-feed">
            <div class="db-empty"><span class="db-spinner"></span></div>
          </div>

          <div class="db-audit-badge ok" id="db-audit-badge">
            <span id="db-audit-icon">🔒</span>
            <span id="db-audit-text">Audit chain: checking…</span>
          </div>
        </div>
      </div>

      <%-- Mini sparkline (legacy, device 1) --%>
      <div class="db-panel">
        <div class="db-panel__head">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#1d6fa4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
          <h3>Live sensor feed — Device 1</h3>
          <span class="db-panel__meta">Door (s) · Weight (g)</span>
        </div>
        <div class="db-panel__body" style="padding:12px 16px;">
          <canvas id="liveChart" width="440" height="180" style="width:100%;height:180px;border:none;padding:0;background:transparent;"></canvas>
        </div>
      </div>

    </div><%-- /right col --%>

  </div><%-- /db-center --%>

</div><%-- /db-wrap --%>

<%-- Slot info modal --%>
<div class="db-modal-backdrop" id="db-modal" onclick="closeModal(event)">
  <div class="db-modal">
    <button class="db-modal-close" onclick="closeModal()">&times;</button>
    <h4 id="db-modal-title">Slot detail</h4>
    <dl id="db-modal-body"></dl>
  </div>
</div>

<script src="${pageContext.request.contextPath}/js/app.js"></script>
<script>
'use strict';

// ── Unregister stray Service Workers on localhost that intercept and fail fetch requests ──
if (typeof navigator !== 'undefined' && 'serviceWorker' in navigator) {
  navigator.serviceWorker.getRegistrations().then(function (registrations) {
    for (var i = 0; i < registrations.length; i++) {
      registrations[i].unregister();
    }
  }).catch(function () {});
}

/* ════════════════════════════════════════════════════════════════════════════
   Dashboard Real-time Engine — Vanilla JS ES6+

   Design rules:
   1. No overlapping requests: setTimeout is scheduled only AFTER the previous
      fetch resolves/rejects (recursive, not setInterval).
   2. Differential DOM updates: only elements whose values actually changed are
      touched — no innerHTML of the whole card, no layout shift.
   3. XSS safety: every server string goes through esc() before reaching HTML.
   4. AbortController timeout: 4 s; if the API hangs we get a clean abort, not
      a silent hang.
   ══════════════════════════════════════════════════════════════════════════ */

const API_URL = '${pageContext.request.contextPath}/api/dashboard';
const CTX     = '${pageContext.request.contextPath}';

let pollCount  = 0;
let pollTimer  = null;
let abortCtrl  = null;

// Last known values for differential updates
const LAST = {};

// ── XSS helper ──────────────────────────────────────────────────────────────
function esc(s) {
  if (s == null) return '';
  return String(s)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;').replace(/'/g,'&#x27;');
}

// ── Differential text setter ─────────────────────────────────────────────────
function setNum(id, val) {
  const el = document.getElementById(id);
  if (!el) return;
  const s = String(val);
  if (el.textContent !== s) {
    el.textContent = s;
    el.classList.remove('num-changed');
    // force reflow so re-adding the class re-triggers the animation
    void el.offsetWidth;
    el.classList.add('num-changed');
  }
}
function setText(id, val) {
  const el = document.getElementById(id);
  if (el && el.textContent !== val) el.textContent = val;
}
function setHTML(id, html) {
  const el = document.getElementById(id);
  if (el) el.innerHTML = html;
}

// ── Connection status (Uses BEM modifier classes to prevent app.css collision) ─
function setStatus(state) {
  const dot   = document.getElementById('db-dot');
  const label = document.getElementById('db-connection-label');
  if (!dot || !label) return;
  dot.className = 'db-live-dot';
  if (state === 'live') {
    label.textContent = 'LIVE';
  } else if (state === 'warn') {
    dot.classList.add('db-live-dot--warn');
    label.textContent = 'RECONNECTING…';
  } else {
    dot.classList.add('db-live-dot--error');
    label.textContent = 'DISCONNECTED';
  }
}

// ── KPI updater ──────────────────────────────────────────────────────────────
function updateKpis(kpis) {
  const total = kpis.totalSlots || 0;

  setNum('kv-avail',  kpis.availableSlots  || 0);
  setNum('kv-occ',    kpis.occupiedSlots   || 0);
  setNum('kv-over',   kpis.overdueSessions || 0);
  setNum('kv-alert',  kpis.activeAlerts    || 0);
  setNum('kv-device', kpis.offlineDevices  || 0);

  const setPct = (id, n) => {
    const el = document.getElementById(id);
    if (el) el.style.width = (total > 0 ? Math.round(n / total * 100) : 0) + '%';
  };
  setPct('kb-avail', kpis.availableSlots  || 0);
  setPct('kb-occ',   kpis.occupiedSlots   || 0);
  setPct('kb-over',  kpis.overdueSessions || 0);

  // Badge colouring for overdue KPI card
  const kpiOver = document.getElementById('kpi-over');
  if (kpiOver) {
    kpiOver.className = 'db-kpi ' + ((kpis.overdueSessions > 0) ? 'kpi--red' : 'kpi--amber');
  }
  // Badge for alerts
  const kpiAlert = document.getElementById('kpi-alert');
  if (kpiAlert) {
    let badge = kpiAlert.querySelector('.db-kpi__badge');
    if (kpis.activeAlerts > 0) {
      if (!badge) {
        badge = document.createElement('span');
        badge.className = 'db-kpi__badge badge--crit';
        kpiAlert.appendChild(badge);
      }
      badge.textContent = kpis.activeAlerts + ' OPEN';
    } else if (badge) {
      badge.remove();
    }
  }

  setText('db-total-label', total + ' total');

  // Audit chain
  const auditBadge = document.getElementById('db-audit-badge');
  const auditText  = document.getElementById('db-audit-text');
  const auditIcon  = document.getElementById('db-audit-icon');
  if (auditBadge) {
    if (kpis.auditChainValid) {
      auditBadge.className = 'db-audit-badge ok';
      auditIcon.textContent = '🔒';
      auditText.textContent = 'Audit chain: VERIFIED — no tampering detected';
    } else {
      auditBadge.className = 'db-audit-badge bad';
      auditIcon.textContent = '⚠️';
      auditText.textContent = 'Audit chain: COMPROMISED — integrity check failed!';
    }
  }
}

// ── Area breakdown ────────────────────────────────────────────────────────────
function updateAreaBreakdown(rows) {
  if (!rows || rows.length === 0) {
    setHTML('db-area-tbody', '<tr><td colspan="4" class="db-empty">No area data</td></tr>');
    return;
  }
  let html = '';
  for (const r of rows) {
    const pct   = r.total > 0 ? Math.round(r.occupied / r.total * 100) : 0;
    const faultPct = r.total > 0 ? Math.round(r.fault / r.total * 100) : 0;
    const barColor = pct >= 90 ? 'var(--db-red)' : pct >= 70 ? 'var(--db-amber)' : 'var(--db-blue)';
    html += '<tr>' +
      '<td><strong>' + esc(r.areaCode) + '</strong> <span style="color:#888;font-size:11px">' + esc(r.areaName) + '</span></td>' +
      '<td>' + r.total + '</td>' +
      '<td style="text-align:right">' +
        '<span class="db-occ-pct">' + pct + '%</span>' +
        '<span class="db-area-table"><span class="occupancy-bar-wrap"><span class="occupancy-bar" style="width:' + pct + '%;background:' + barColor + '"></span></span></span>' +
      '</td>' +
      '<td style="text-align:right;color:' + (r.fault > 0 ? 'var(--db-red)' : '#aaa') + '">' + (r.fault || 0) + '</td>' +
      '</tr>';
  }
  setHTML('db-area-tbody', html);
}

// ── Alert feed ─────────────────────────────────────────────────────────────────
const SEV_ICON = { CRITICAL: '🔴', WARNING: '🟠', INFO: '🔵' };

function updateAlertFeed(alerts) {
  const feed = document.getElementById('db-alert-feed');
  if (!feed) return;
  if (!alerts || alerts.length === 0) {
    feed.innerHTML = '<div class="db-empty">No recent alerts — system normal ✓</div>';
    return;
  }
  let html = '';
  for (const a of alerts) {
    const sev  = esc(a.severity || 'INFO');
    const risk = a.riskScore != null ? (a.riskScore * 100).toFixed(0) + '%' : '—';
    const riskColor = a.riskScore != null
      ? (a.riskScore >= 0.7 ? 'var(--db-red)' : a.riskScore >= 0.4 ? 'var(--db-amber)' : 'var(--db-blue)')
      : '#aaa';
    html +=
      '<div class="db-alert-item sev-' + sev + '">' +
        '<span class="db-alert-item__icon">' + (SEV_ICON[a.severity] || '⚪') + '</span>' +
        '<div class="db-alert-item__body">' +
          '<div class="db-alert-item__label">' + esc(a.label) + '</div>' +
          '<div class="db-alert-item__sub">' +
            esc(a.deviceCode || 'Device ' + a.deviceId) + ' · ' +
            esc(a.source) + ' · ' + esc(a.createdAt) +
          '</div>' +
        '</div>' +
        '<div class="db-alert-item__risk" style="color:' + riskColor + '">' + risk + '</div>' +
      '</div>';
  }
  feed.innerHTML = html;
}

// ── Device health ─────────────────────────────────────────────────────────────
function updateDeviceHealth(devices) {
  const list = document.getElementById('db-device-list');
  if (!list) return;
  if (!devices || devices.length === 0) {
    list.innerHTML = '<div class="db-empty">No devices registered</div>';
    return;
  }
  const onlineCount = devices.filter(d => d.health === 'ONLINE').length;
  setText('db-online-label', onlineCount + '/' + devices.length + ' online');

  let html = '';
  for (const d of devices) {
    const hclass = d.health === 'ONLINE' ? 'h-online' : d.health === 'DEGRADED' ? 'h-degraded' : 'h-offline';
    const hb = d.lastSeenSec != null ? d.lastSeenSec + ' s ago' : 'never';
    html +=
      '<div class="db-device-row">' +
        '<span class="db-device-row__code">' + esc(d.deviceCode) + '</span>' +
        '<span class="db-device-row__loc">' + esc(d.location || '—') + '</span>' +
        '<span class="db-hbadge ' + hclass + '">' + esc(d.health) + '</span>' +
        '<span class="db-device-row__hb">' + hb + '</span>' +
      '</div>';
  }
  list.innerHTML = html;
}

// ── Sparkline canvas chart ────────────────────────────────────────────────────
function drawSeries(ctx2d, values, w, h, color) {
  if (values.length < 2) return;
  const max = Math.max(...values), min = Math.min(...values), range = (max - min) || 1;
  ctx2d.strokeStyle = color; ctx2d.lineWidth = 2;
  ctx2d.beginPath();
  values.forEach((v, i) => {
    const x = i * w / (values.length - 1);
    const y = h - (v - min) / range * (h - 20) - 10;
    i === 0 ? ctx2d.moveTo(x, y) : ctx2d.lineTo(x, y);
  });
  ctx2d.stroke();
}

function refreshSparkline() {
  fetch(API_URL + '?device=1', { credentials: 'same-origin' })
    .then(r => r.ok ? r.json() : Promise.reject(r.status))
    .then(rows => {
      const canvas = document.getElementById('liveChart');
      if (!canvas) return;
      const c = canvas.getContext('2d');
      c.clearRect(0, 0, canvas.width, canvas.height);
      drawSeries(c, rows.map(r => r.a), canvas.width, canvas.height, '#1d6fa4');
      drawSeries(c, rows.map(r => r.b), canvas.width, canvas.height, '#c0392b');
    })
    .catch(() => {});
}

// ── Main poll cycle ───────────────────────────────────────────────────────────
function fetchDashboard() {
  if (abortCtrl) abortCtrl.abort();
  abortCtrl = new AbortController();
  const timeout = setTimeout(() => abortCtrl.abort(), 4000);
  const fetchUrl = API_URL + '?_=' + Date.now();

  fetch(fetchUrl, { credentials: 'same-origin', cache: 'no-store', signal: abortCtrl.signal })
    .then(r => { clearTimeout(timeout); return r.ok ? r.json() : Promise.reject(r.status); })
    .then(data => {
      setStatus('live');
      pollCount++;
      setText('db-poll-count', pollCount + ' polls');
      setText('db-server-time', data.serverTime || '—');

      if (data.kpis)          updateKpis(data.kpis);
      if (data.slotBreakdown) updateAreaBreakdown(data.slotBreakdown);
      if (data.recentAlerts)  updateAlertFeed(data.recentAlerts);
      if (data.deviceHealth)  updateDeviceHealth(data.deviceHealth);

      scheduleNext();
    })
    .catch(err => {
      clearTimeout(timeout);
      console.warn('Dashboard poll warning:', err);
      // If server or network hiccup, show RECONNECTING... and retry after 3s
      setStatus('warn');
      scheduleNext(3000);
    });
}

function scheduleNext(overrideMs) {
  if (pollTimer) clearTimeout(pollTimer);
  const interval = parseInt(document.getElementById('db-interval-sel').value, 10);
  const delay = (overrideMs !== undefined) ? overrideMs : interval;
  if (delay === 0 && overrideMs === undefined) return;   // paused
  pollTimer = setTimeout(fetchDashboard, delay);
}

// ── Modal ─────────────────────────────────────────────────────────────────────
function closeModal(e) {
  if (!e || e.target === document.getElementById('db-modal') || e.currentTarget === document.querySelector('.db-modal-close')) {
    document.getElementById('db-modal').classList.remove('open');
  }
}

// ── Boot ─────────────────────────────────────────────────────────────────────
fetchDashboard();
setInterval(refreshSparkline, 5000);
</script>
</body>
</html>
