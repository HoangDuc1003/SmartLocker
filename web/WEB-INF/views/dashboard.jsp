<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="dashboard"/>
<%-- Operations overview. DashboardController sets kpis, devices, roleLabels, roleValues, recentSessions for the first paint;
     js/dashboard.js then refreshes the numbers from /api/dashboard (the LockerMonitor snapshot, no DB query per poll). --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Dashboard · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap" data-api="${ctx}/api/dashboard" data-stats-api="${ctx}/api/dashboard/stats" data-alert-url="${ctx}/AlertController">

    <div class="page-head">
        <div>
            <h2>Operations dashboard</h2>
            <p class="sub">Figures refresh from the server automatically. <span id="db-time"></span></p>
        </div>
        <div class="sync">
            <span class="sync__state" id="db-state" data-state="idle" role="status" aria-live="polite">Connecting…</span>
            <label class="visually-hidden" for="db-interval">Refresh interval</label>
            <select id="db-interval">
                <option value="5000" selected>Refresh every 5 s</option>
                <option value="15000">Every 15 s</option>
                <option value="60000">Every 1 min</option>
                <option value="0">Paused</option>
            </select>
            <button type="button" class="ghost" id="db-refresh">Refresh</button>
        </div>
    </div>

    <%-- ===== KPI cards ===== --%>
    <c:set var="total" value="${not empty kpis ? kpis.totalSlots : 0}"/>
    <section class="cards" aria-label="Key figures">
        <div class="card">
            <span class="cap">Total slots</span>
            <span class="num" id="k-total">${total}</span>
            <div class="meter" aria-hidden="true">
                <span class="m-ok" id="m-avail" style="width:${total > 0 ? kpis.availableSlots * 100 / total : 0}%"></span>
                <span class="m-use" id="m-occ" style="width:${total > 0 ? kpis.occupiedSlots * 100 / total : 0}%"></span>
                <span class="m-bad" id="m-fault" style="width:${total > 0 ? kpis.maintenanceOrFaultSlots * 100 / total : 0}%"></span>
            </div>
            <div class="legend">
                <span><i class="ok"></i>Available <b id="k-avail">${not empty kpis ? kpis.availableSlots : 0}</b></span>
                <span><i class="use"></i>Occupied <b id="k-occ">${not empty kpis ? kpis.occupiedSlots : 0}</b></span>
                <span><i class="bad"></i>Fault/maintenance <b id="k-fault">${not empty kpis ? kpis.maintenanceOrFaultSlots : 0}</b></span>
            </div>
        </div>
        <div class="card">
            <span class="cap">Occupancy rate</span>
            <span class="num" id="k-rate"><c:choose><c:when test="${total > 0}"><fmt:formatNumber value="${kpis.occupiedSlots * 100.0 / total}" maxFractionDigits="1"/>%</c:when><c:otherwise>0%</c:otherwise></c:choose></span>
            <div class="foot">Overdue bookings: <b id="k-over">${not empty kpis ? kpis.overdueSessions : 0}</b></div>
        </div>
        <a class="card ${not empty kpis and kpis.activeAlerts > 0 ? 'warn' : ''}" id="c-alerts" href="${ctx}/AlertController?status=OPEN">
            <span class="cap">Open alerts</span>
            <span class="num" id="k-alerts">${not empty kpis ? kpis.activeAlerts : 0}</span>
            <div class="foot">View the alert list</div>
        </a>
        <div class="card ${not empty kpis and kpis.offlineDevices > 0 ? 'warn' : ''}" id="c-offline">
            <span class="cap">Offline devices</span>
            <span class="num" id="k-offline">${not empty kpis ? kpis.offlineDevices : 0}</span>
            <div class="foot" id="k-online">&nbsp;</div>
        </div>
        <div class="card ${not empty kpis and not kpis.auditChainValid ? 'warn' : 'ok'}" id="c-audit">
            <span class="cap">Audit log chain</span>
            <span class="num" id="k-audit" style="font-size:20px">${not empty kpis and not kpis.auditChainValid ? 'Tampered' : 'Intact'}</span>
            <c:if test="${perms.contains('AUDIT:READ')}"><div class="foot"><a href="${ctx}/AuditController">Open the audit log</a></div></c:if>
        </div>
    </section>

    <%-- ===== Charts: js/dash-charts.js fills the .chart-body boxes from /api/dashboard and /api/dashboard/stats ===== --%>
    <section class="chart-grid" aria-label="Operations charts">
        <article class="chart-card">
            <h3>Slot status</h3>
            <p class="sub">Whole system, in real time.</p>
            <div class="chart-body" id="ch-slots"><p class="chart-empty">Loading…</p></div>
        </article>
        <article class="chart-card chart-card--8">
            <h3>Usage by area</h3>
            <p class="sub">Click an area name to open its locker map.</p>
            <div class="chart-body" id="ch-areas"><p class="chart-empty">Loading…</p></div>
        </article>
        <article class="chart-card">
            <h3>Devices</h3>
            <p class="sub">From the latest heartbeat of each box.</p>
            <div class="chart-body" id="ch-devices"><p class="chart-empty">Loading…</p></div>
        </article>
        <article class="chart-card">
            <h3>Open alerts</h3>
            <p class="sub">By type. <a href="${ctx}/AlertController?status=OPEN">View the list</a></p>
            <div class="chart-body" id="ch-alerts"><p class="chart-empty">Loading…</p></div>
        </article>
        <article class="chart-card" id="card-revenue" hidden>
            <h3>Storage revenue</h3>
            <p class="sub" id="ch-revenue-meta">Last 7 days.</p>
            <div class="chart-body" id="ch-revenue"><p class="chart-empty">Loading…</p></div>
        </article>
        <article class="chart-card chart-card--6">
            <h3>Bookings by hour</h3>
            <p class="sub" id="ch-hourly-meta">Vietnam time, today compared with yesterday.</p>
            <div class="chart-body" id="ch-hourly"><p class="chart-empty">Loading…</p></div>
        </article>
        <article class="chart-card chart-card--6">
            <h3>Busiest hours</h3>
            <p class="sub">Bookings by weekday and hour over the last 4 weeks.</p>
            <div class="chart-body" id="ch-heat"><p class="chart-empty">Loading…</p></div>
        </article>
    <section class="chart-card chart-card--12">
        <div class="panel-head">
            <h3>Sensors by device</h3>
            <label class="visually-hidden" for="db-device">Device</label>
            <select id="db-device">
                <c:forEach var="d" items="${devices}">
                    <option value="${d.deviceId}"><c:out value="${d.deviceCode}"/></option>
                </c:forEach>
            </select>
        </div>
        <div class="seg" role="group" aria-label="Shown measure" style="margin-bottom:10px">
            <button type="button" data-mode="a" aria-pressed="true">Door-open time (s)</button>
            <button type="button" data-mode="b" aria-pressed="false">Weight change (g)</button>
        </div>
        <div class="chart-box">
            <canvas id="db-chart" role="img" aria-label="Chart of the last 50 opening sessions of the chosen device"></canvas>
            <div class="chart-tip" id="db-tip" hidden></div>
        </div>
        <p class="hint" id="db-chart-meta" style="margin-top:8px"></p>
    </section>
    </section>

    <%-- ===== The tables, folded: the charts above answer the usual questions ===== --%>
    <details class="fold">
        <summary>Detail tables: areas, devices, alerts and opening sessions</summary>
    <div class="grid-2">
        <section class="panel">
            <div class="panel-head">
                <h3>By area</h3>
                <a href="${ctx}/LockerMapController">Open the locker map</a>
            </div>
            <div class="tablewrap">
                <table class="grid">
                    <thead><tr><th>Area</th><th class="r">Total</th><th class="r">Occupied</th><th class="r">Available</th><th class="r">Fault</th></tr></thead>
                    <tbody id="db-areas"><tr><td colspan="5" class="empty">Loading…</td></tr></tbody>
                </table>
            </div>
        </section>

        <section class="panel">
            <div class="panel-head">
                <h3>Devices</h3>
                <span class="muted" id="db-online"></span>
            </div>
            <div class="tablewrap">
                <table class="grid">
                    <thead><tr><th>Device</th><th>Location</th><th>Status</th><th class="r">Last seen</th></tr></thead>
                    <tbody id="db-devices">
                        <c:forEach var="d" items="${devices}">
                            <tr><td><b><c:out value="${d.deviceCode}"/></b></td><td><c:out value="${d.location}"/></td>
                                <td><ui:status value="${d.status}"/></td><td class="r muted">–</td></tr>
                        </c:forEach>
                        <c:if test="${empty devices}"><tr><td colspan="4" class="empty">No devices yet.</td></tr></c:if>
                    </tbody>
                </table>
            </div>
        </section>
    </div>


    <div class="grid-2" style="margin-top:16px">
        <section class="panel">
            <div class="panel-head">
                <h3>Recent alerts</h3>
                <a href="${ctx}/AlertController">All alerts</a>
            </div>
            <div class="tablewrap">
                <table class="grid">
                    <thead><tr><th>Type</th><th>Device</th><th class="r">Risk</th><th>Time</th></tr></thead>
                    <tbody id="db-alerts"><tr><td colspan="4" class="empty">Loading…</td></tr></tbody>
                </table>
            </div>
        </section>
    </div>

    <section class="panel" style="margin-top:16px">
        <div class="panel-head">
            <h3>Recent opening sessions</h3>
            <div class="seg" role="group" aria-label="Filter sessions" id="db-session-filter">
                <button type="button" data-filter="all" aria-pressed="true">All</button>
                <button type="button" data-filter="door" aria-pressed="false">Long open (&gt;10 s)</button>
                <button type="button" data-filter="weight" aria-pressed="false">Items changed</button>
                <button type="button" data-filter="denied" aria-pressed="false">Card denied</button>
            </div>
        </div>
        <div class="tablewrap">
            <table class="grid">
                <thead><tr><th>Session</th><th>Device · Slot</th><th>Card UID</th><th class="r">Door open</th><th class="r">Weight</th><th>Card</th><th>Open method</th><th>Measured</th></tr></thead>
                <tbody id="db-sessions">
                    <c:forEach var="s" items="${recentSessions}">
                        <tr data-door="${s.door_open_sec}" data-weight="${s.weight_delta_g}" data-rfid="${s.rfid_ok}">
                            <td class="num">#${s.session_id}</td>
                            <td>Device #${s.device_id} · <b><c:out value="${not empty s.slot_code ? s.slot_code : s.slot_id}"/></b></td>
                            <td><code><c:out value="${not empty s.card_uid ? s.card_uid : '–'}"/></code></td>
                            <td class="r num"><fmt:formatNumber value="${s.door_open_sec}" maxFractionDigits="1"/> s</td>
                            <td class="r num"><fmt:formatNumber value="${s.weight_delta_g}" maxFractionDigits="0"/> g</td>
                            <td><span class="tag ${s.rfid_ok ? 'ok' : 'bad'}">${s.rfid_ok ? 'Valid' : 'Denied'}</span></td>
                            <td><c:out value="${not empty s.open_source ? s.open_source : 'CARD'}"/></td>
                            <td><ui:dt value="${s.measured_at}"/></td>
                        </tr>
                    </c:forEach>
                    <c:if test="${empty recentSessions}"><tr><td colspan="8" class="empty">No opening sessions yet.</td></tr></c:if>
                </tbody>
            </table>
        </div>
    </section>

    </details>

    <c:if test="${not empty roleLabels}">
        <section class="panel" style="margin-top:16px">
            <h3>Users by role</h3>
            <c:set var="roleMax" value="1"/>
            <c:forEach var="v" items="${roleValues}"><c:if test="${v > roleMax}"><c:set var="roleMax" value="${v}"/></c:if></c:forEach>
            <c:forEach var="label" items="${roleLabels}" varStatus="st">
                <div class="bar-row">
                    <span><c:out value="${label}"/></span>
                    <span class="bar-row__track"><span class="bar-row__fill" style="display:block;width:${roleValues[st.index] * 100 / roleMax}%"></span></span>
                    <span class="r num">${roleValues[st.index]}</span>
                </div>
            </c:forEach>
        </section>
    </c:if>
</main>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/dash-charts.js"></script>
<script src="${ctx}/js/dashboard.js"></script>
</body>
</html>
