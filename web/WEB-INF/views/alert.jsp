<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="alerts"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Alerts · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= DETAIL ================= --%>
<c:when test="${mode == 'detail'}">
    <div class="page-head">
        <div>
            <h2>Alert #${alert.alertId}: <c:out value="${alert.label}"/></h2>
        </div>
        <a class="btn ghost" href="${ctx}/AlertController">Back to the list</a>
    </div>

    <div class="grid-2">
        <section class="panel">
            <h3>Details</h3>
            <dl class="kv">
                <dt>Status</dt><dd><ui:status value="${alert.status}"/></dd>
                <dt>Detected by</dt><dd><c:out value="${alert.source == 'ML' ? 'Machine learning model (ML)' : 'Rule (RULE)'}"/></dd>
                <dt>Time</dt><dd><ui:dt value="${alert.createdAt}"/></dd>
                <c:if test="${not empty alert.riskScore}">
                    <%-- risk = 1 - P(NORMAL), shown as a whole percent like the list and the dashboard --%>
                    <dt>Risk score</dt><dd class="num"><fmt:formatNumber value="${alert.riskScore}" type="percent" maxFractionDigits="0"/></dd>
                </c:if>
                <dt>Device</dt>
                <dd>
                    <c:choose>
                        <c:when test="${not empty device}">
                            <b><c:out value="${device.deviceCode}"/></b> · <c:out value="${device.location}"/>
                            <ui:status value="${device.status}"/>
                        </c:when>
                        <c:otherwise>Device #${alert.deviceId}</c:otherwise>
                    </c:choose>
                </dd>
            </dl>
            <c:if test="${alert.status == 'OPEN' and perms.contains('ALERT:WRITE')}">
                <form method="post" action="${ctx}/AlertController" class="actions" data-confirm="Mark this alert as resolved?">
                    <input type="hidden" name="action" value="resolve">
                    <input type="hidden" name="id" value="${alert.alertId}">
                    <button type="submit">Mark as resolved</button>
                </form>
            </c:if>
        </section>

        <c:if test="${not empty device and perms.contains('ALERT:WRITE')}">
            <section class="panel">
                <h3>Device status</h3>
                <p class="muted" style="margin-top:0">After checking or repairing it, the technician sets the status of the controller
                    <b><c:out value="${device.deviceCode}"/></b>.</p>
                <form method="post" action="${ctx}/AlertController" class="actions">
                    <input type="hidden" name="action" value="device_status">
                    <input type="hidden" name="alertId" value="${alert.alertId}">
                    <input type="hidden" name="deviceId" value="${device.deviceId}">
                    <button type="submit" name="status" value="ACTIVE" class="btn--ok" ${device.status == 'ACTIVE' ? 'disabled' : ''}>Back in service</button>
                    <button type="submit" name="status" value="MAINTENANCE" class="ghost" ${device.status == 'MAINTENANCE' ? 'disabled' : ''}>Set to maintenance</button>
                    <button type="submit" name="status" value="OFFLINE" class="btn--danger" ${device.status == 'OFFLINE' ? 'disabled' : ''}
                            data-confirm="Mark the device as offline?" data-confirm-danger>Mark as offline</button>
                </form>
            </section>
        </c:if>
    </div>

    <%-- v3 D5: a booking past due for ESCALATE_HOURS, opened by Deposit_Escalate with its evidence --%>
    <c:if test="${alert.label == 'OVERDUE_ESCALATED'}">
        <c:forEach var="ev" items="${alert.evidence}">
            <c:choose>
                <c:when test="${ev[0] == 'deposit_id'}"><c:set var="escDeposit" value="${ev[1]}"/></c:when>
                <c:when test="${ev[0] == 'user'}"><c:set var="escUser" value="${ev[1]}"/></c:when>
                <c:when test="${ev[0] == 'slot'}"><c:set var="escSlot" value="${ev[1]}"/></c:when>
                <c:when test="${ev[0] == 'due_at_utc'}"><c:set var="escDue" value="${ev[1]}"/></c:when>
                <c:when test="${ev[0] == 'hours_late'}"><c:set var="escHours" value="${ev[1]}"/></c:when>
                <c:when test="${ev[0] == 'overdue_fee'}"><c:set var="escFee" value="${ev[1]}"/></c:when>
                <c:when test="${ev[0] == 'balance'}"><c:set var="escBalance" value="${ev[1]}"/></c:when>
            </c:choose>
        </c:forEach>
        <section class="panel esc-panel">
            <h3>Overdue booking escalated to staff</h3>
            <p class="hint">The items are still in the slot and the locker is locked. Contact the user; reporting to the authorities (if needed) is done outside the system.</p>
            <%-- the UTC text is read as a wall clock in the JVM zone, the same frame as JDBC timestamps, so ui:dt prints it in Vietnam time --%>
            <c:if test="${not empty escDue}"><c:catch var="escDueBad"><fmt:parseDate var="escDueAt" value="${escDue}" pattern="yyyy-MM-dd HH:mm:ss"/></c:catch></c:if>
            <dl class="kv">
                <dt>Booking</dt><dd><c:out value="#${escDeposit}"/>
                    <c:if test="${perms.contains('DEPOSIT:READ')}"><c:url var="escLink" value="/DepositController"><c:param name="q" value="${escUser}"/></c:url><a href="<c:out value='${escLink}'/>">View booking</a></c:if></dd>
                <dt>User</dt><dd><b><c:out value="${escUser}"/></b></dd>
                <dt>Slot</dt><dd><c:out value="${escSlot}"/></dd>
                <dt>Due</dt><dd><ui:dt value="${escDueAt}"/></dd>
                <dt>Hours late</dt><dd class="num"><c:out value="${escHours}"/> h</dd>
                <dt>Late fee charged</dt><dd><span class="money"><fmt:formatNumber value="${escFee}" groupingUsed="true"/> VND</span></dd>
                <dt>Amount owed</dt><dd><span class="money ${escBalance lt 0 ? 'text-danger' : ''}"><fmt:formatNumber value="${escBalance lt 0 ? -escBalance : 0}" groupingUsed="true"/> VND</span>
                    <span class="muted">(balance when escalated: <fmt:formatNumber value="${escBalance}" groupingUsed="true"/> VND)</span></dd>
            </dl>
        </section>
    </c:if>

    <h3>Evidence</h3>
    <div class="tablewrap">
    <table class="grid">
        <tr><th>Item</th><th>Recorded value</th></tr>
        <c:forEach var="ev" items="${alert.evidence}">
            <tr>
                <td><b><c:out value="${ev[0]}"/></b></td>
                <td><code><c:out value="${ev[1]}"/></code></td>
            </tr>
        </c:forEach>
        <c:if test="${empty alert.evidence}">
            <tr><td colspan="2" class="empty">No evidence attached.</td></tr>
        </c:if>
    </table>
    </div>

    <c:if test="${not empty session}">
        <h3>Opening session that raised the alert (#${session.sessionId})</h3>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Slot</th><th>Card UID</th><th>Open method</th><th class="r">Door open (s)</th><th class="r">Weight change (g)</th><th class="r">Openings</th><th class="r">Storage time (min)</th><th>Measured</th></tr>
            <tr>
                <td><c:out value="${session.slotCode}"/></td>
                <td><code><c:out value="${session.cardUid}"/></code></td>
                <td><c:out value="${session.openSource}"/></td>
                <td class="r num"><c:out value="${session.doorOpenSec}"/></td>
                <td class="r num"><c:out value="${session.weightDeltaG}"/></td>
                <td class="r num"><c:out value="${session.unlockCount}"/></td>
                <td class="r num"><c:out value="${session.stayMin}"/></td>
                <td><ui:dt value="${session.measuredAt}"/></td>
            </tr>
        </table>
        </div>
    </c:if>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Alerts <span class="count">(${total})</span></h2>
    </div>

    <form class="filter" method="get" action="${ctx}/AlertController">
        <select name="status" aria-label="Status">
            <option value="">All statuses</option>
            <option value="OPEN" ${status == 'OPEN' ? 'selected' : ''}>Open</option>
            <option value="RESOLVED" ${status == 'RESOLVED' ? 'selected' : ''}>Resolved</option>
        </select>
        <input type="text" name="label" value="<c:out value='${label}'/>" placeholder="Filter by alert type" aria-label="Alert type">
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/AlertController">Clear filters</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Time</th><th>Device</th><th>Type</th><th>Source</th><th class="r">Risk</th><th>Status</th><th>Actions</th></tr>
        <c:forEach var="a" items="${items}">
        <tr class="${a.status == 'OPEN' ? 'locked' : ''}">
            <td><a href="${ctx}/AlertController?id=${a.alertId}">#${a.alertId}</a></td>
            <td><ui:dt value="${a.createdAt}"/></td>
            <td><c:choose><c:when test="${not empty a.deviceCode}"><b><c:out value="${a.deviceCode}"/></b></c:when><c:otherwise>Device #${a.deviceId}</c:otherwise></c:choose></td>
            <td><b><c:out value="${a.label}"/></b></td>
            <td><c:out value="${a.source}"/></td>
            <td class="r num"><c:choose><c:when test="${not empty a.riskScore}"><fmt:formatNumber value="${a.riskScore}" type="percent" maxFractionDigits="0"/></c:when><c:otherwise>–</c:otherwise></c:choose></td>
            <td><ui:status value="${a.status}"/></td>
            <td class="ops">
                <a href="${ctx}/AlertController?id=${a.alertId}">Details</a>
                <c:if test="${a.status == 'OPEN' and perms.contains('ALERT:WRITE')}">
                    <form method="post" action="${ctx}/AlertController" data-confirm="Mark this alert as resolved?">
                        <input type="hidden" name="action" value="resolve">
                        <input type="hidden" name="id" value="${a.alertId}">
                        <button type="submit" class="link">Resolve</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="empty">No alerts.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/AlertController">
                        <c:param name="status" value="${status}"/>
                        <c:param name="label" value="${label}"/>
                        <c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</c:otherwise>

</c:choose>
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
