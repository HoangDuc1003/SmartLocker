<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="maintenance"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Maintenance tickets · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <h2>Maintenance tickets <span class="count">(${total})</span></h2>
    </div>

    <form class="filter" method="get" action="${ctx}/MaintenanceController">
        <select name="status" aria-label="Status">
            <option value="">All statuses</option>
            <option value="OPEN" ${status == 'OPEN' ? 'selected' : ''}>Open</option>
            <option value="CLOSED" ${status == 'CLOSED' ? 'selected' : ''}>Closed</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/MaintenanceController">Clear filters</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Device</th><th>Alert</th><th>Assigned to</th><th>Note</th><th>Status</th><th>Opened</th><th>Closed</th><th>Actions</th></tr>
        <c:forEach var="t" items="${items}">
        <tr class="${t.status == 'OPEN' ? 'locked' : ''} ${hlId == t.ticket_id ? 'hl' : ''}">
            <td class="num">${t.ticket_id}</td>
            <td><c:out value="${t.device_code}"/></td>
            <td>
                <c:if test="${not empty t.alert_id}"><a href="${ctx}/AlertController?id=${t.alert_id}">#${t.alert_id}</a></c:if>
            </td>
            <td><c:out value="${t.assigned_to_name}"/></td>
            <td><c:out value="${t.note}"/></td>
            <td><ui:status value="${t.status}"/></td>
            <td><ui:dt value="${t.opened_at}"/></td>
            <td><ui:dt value="${t.closed_at}"/></td>
            <td class="ops">
                <c:choose>
                    <c:when test="${t.status == 'OPEN' and perms.contains('MAINTENANCE:WRITE')}">
                        <form method="post" action="${ctx}/MaintenanceController" data-confirm="Close the ticket and put the slot back in service?">
                            <input type="hidden" name="action" value="close">
                            <input type="hidden" name="ticketId" value="${t.ticket_id}">
                            <input type="text" name="note" placeholder="Repair note" aria-label="Repair note for ticket ${t.ticket_id}">
                            <button type="submit" class="btn--sm ghost">Close ticket</button>
                        </form>
                    </c:when>
                    <c:otherwise><span class="muted">–</span></c:otherwise>
                </c:choose>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="9" class="empty">No maintenance tickets.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
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
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
