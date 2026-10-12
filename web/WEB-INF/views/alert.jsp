<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="alerts"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Alerts</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= DETAIL ================= --%>
<c:when test="${mode == 'detail'}">
    <h2>Alert #${alert.alertId}: <c:out value="${alert.label}"/></h2>

    <div style="background:var(--bg-panel, #f8f9fa);padding:16px;border-radius:8px;margin-bottom:20px;border:1px solid var(--border, #dee2e6);">
        <p><b>Status:</b> <span class="badge ${alert.status == 'OPEN' ? 'danger' : ''}">${alert.status}</span></p>
        <p><b>Source:</b> ${alert.source}</p>
        <p><b>Device:</b> Device #${alert.deviceId}</p>
        <p><b>Created:</b> ${alert.createdAt}</p>
        <c:if test="${not empty alert.riskScore}">
            <p><b>Risk score:</b> ${alert.riskScore}</p>
        </c:if>
    </div>

    <h3>Evidence</h3>
    <div class="tablewrap" style="margin-bottom:20px;">
    <table class="grid">
        <tr><th>Evidence Item</th><th>Recorded Value</th></tr>
        <c:forEach var="ev" items="${alert.evidence}">
            <tr>
                <td><b><c:out value="${ev[0]}"/></b></td>
                <td><code><c:out value="${ev[1]}"/></code></td>
            </tr>
        </c:forEach>
        <c:if test="${empty alert.evidence}">
            <tr><td colspan="2" class="c">No specific evidence attached</td></tr>
        </c:if>
    </table>
    </div>

    <c:if test="${not empty session}">
        <h3>Triggering Session (#${session.sessionId})</h3>
        <div class="tablewrap" style="margin-bottom:20px;">
        <table class="grid">
            <tr><th>Slot</th><th>Card UID</th><th>Open source</th><th>Door open (s)</th><th>Weight delta (g)</th><th>Unlocks</th><th>Stay (min)</th><th>Measured at</th></tr>
            <tr>
                <td><c:out value="${session.slotCode}"/></td>
                <td><code><c:out value="${session.cardUid}"/></code></td>
                <td>${session.openSource}</td>
                <td>${session.doorOpenSec}</td>
                <td>${session.weightDeltaG}</td>
                <td>${session.unlockCount}</td>
                <td>${session.stayMin}</td>
                <td>${session.measuredAt}</td>
            </tr>
        </table>
        </div>
    </c:if>

    <div class="actions">
        <c:if test="${alert.status == 'OPEN'}">
            <form method="post" action="${ctx}/AlertController" onsubmit="return confirm('Resolve this alert?');" style="display:inline;">
                <input type="hidden" name="action" value="resolve">
                <input type="hidden" name="id" value="${alert.alertId}">
                <button type="submit">Resolve Alert</button>
            </form>
        </c:if>
        <a class="btn ghost" href="${ctx}/AlertController">Back to alerts</a>
    </div>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Alerts (${total})</h2>

    <form class="filter" method="get" action="${ctx}/AlertController">
        <select name="status">
            <option value="">-- All statuses --</option>
            <option value="OPEN" ${status == 'OPEN' ? 'selected' : ''}>OPEN</option>
            <option value="RESOLVED" ${status == 'RESOLVED' ? 'selected' : ''}>RESOLVED</option>
        </select>
        <input type="text" name="label" value="<c:out value='${label}'/>" placeholder="Filter by label">
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/AlertController">Clear</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Time</th><th>Device</th><th>Label</th><th>Source</th><th>Risk</th><th>Status</th><th>Actions</th></tr>
        <c:forEach var="a" items="${items}">
        <tr class="${a.status == 'OPEN' ? 'locked' : ''}">
            <td><a href="${ctx}/AlertController?id=${a.alertId}">#${a.alertId}</a></td>
            <td>${a.createdAt}</td>
            <td>Device #${a.deviceId}</td>
            <td><b><c:out value="${a.label}"/></b></td>
            <td>${a.source}</td>
            <td>${not empty a.riskScore ? a.riskScore : '-'}</td>
            <td class="c">
                <span class="badge ${a.status == 'OPEN' ? 'danger' : ''}">${a.status}</span>
            </td>
            <td class="ops">
                <a href="${ctx}/AlertController?id=${a.alertId}">Details</a>
                <c:if test="${a.status == 'OPEN'}">
                    <form method="post" action="${ctx}/AlertController" onsubmit="return confirm('Resolve alert #${a.alertId}?');" style="display:inline;">
                        <input type="hidden" name="action" value="resolve">
                        <input type="hidden" name="id" value="${a.alertId}">
                        <button type="submit" class="link">Resolve</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
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
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
