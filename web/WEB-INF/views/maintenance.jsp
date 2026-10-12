<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="maintenance"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Maintenance tickets</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>Maintenance tickets (${total})</h2>

    <form class="filter" method="get" action="${ctx}/MaintenanceController">
        <select name="status">
            <option value="">-- All statuses --</option>
            <option value="OPEN" ${status == 'OPEN' ? 'selected' : ''}>OPEN</option>
            <option value="CLOSED" ${status == 'CLOSED' ? 'selected' : ''}>CLOSED</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/MaintenanceController">Clear</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Device</th><th>Alert</th><th>Assigned to</th><th>Note</th><th>Status</th><th>Opened</th><th>Closed</th><th>Actions</th></tr>
        <c:forEach var="t" items="${items}">
        <tr class="${t.status == 'OPEN' ? 'locked' : ''}">
            <td>${t.ticket_id}</td>
            <td><c:out value="${t.device_code}"/></td>
            <td>
                <c:if test="${not empty t.alert_id}">
                    <a href="${ctx}/AlertController?id=${t.alert_id}">#${t.alert_id}</a>
                </c:if>
            </td>
            <td><c:out value="${t.assigned_to_name}"/></td>
            <td><c:out value="${t.note}"/></td>
            <td class="c">${t.status}</td>
            <td>${t.opened_at}</td>
            <td>${t.closed_at}</td>
            <td class="ops">
                <c:choose>
                    <c:when test="${t.status == 'OPEN'}">
                        <form method="post" action="${ctx}/MaintenanceController" style="display:inline-flex;gap:4px;align-items:center;" onsubmit="return confirm('Close this ticket and restore slot?');">
                            <input type="hidden" name="action" value="close">
                            <input type="hidden" name="ticketId" value="${t.ticket_id}">
                            <input type="text" name="note" placeholder="Repair note" style="padding:2px 4px;font-size:12px;width:120px;">
                            <button type="submit" class="link">Close</button>
                        </form>
                    </c:when>
                    <c:otherwise>
                        <span class="muted">Closed</span>
                    </c:otherwise>
                </c:choose>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="9" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/MaintenanceController">
                        <c:param name="status" value="${status}"/>
                        <c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
