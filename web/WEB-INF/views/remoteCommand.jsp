<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="commands"/>
<%-- Remote unlock. RemoteCommandController sets items, total, page, pages, status, and slots (for the form).
     The form posts slotId + reason, the same parameters as the slot panel of the locker map. --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Remote unlock · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <div>
            <h2>Remote unlock <span class="count">(${total})</span></h2>
            <p class="sub">A command is queued and sent to the controller at its next heartbeat (about 10 seconds); it expires after 2 minutes.</p>
        </div>
    </div>

    <c:if test="${perms.contains('COMMAND:WRITE')}">
        <section class="panel" style="margin-bottom:20px">
            <h3>New unlock command</h3>
            <form method="post" action="${ctx}/RemoteCommandController" class="grid-3" style="align-items:end">
                <input type="hidden" name="back" value="list">
                <div class="field">
                    <label for="cmdSlot">Slot</label>
                    <select id="cmdSlot" name="slotId" required>
                        <option value="">Choose a slot</option>
                        <c:forEach var="s" items="${slots}">
                            <option value="${s.slotId}"><c:out value="${s.bankCode}"/> – <c:out value="${s.slotCode}"/></option>
                        </c:forEach>
                    </select>
                </div>
                <div class="field">
                    <label for="cmdReason">Reason (at least 5 characters)</label>
                    <input type="text" id="cmdReason" name="reason" required minlength="5" maxlength="200"
                           placeholder="E.g. Customer forgot the card, ID checked at the front desk">
                </div>
                <div>
                    <button type="submit" class="btn--block" data-confirm="Send an unlock command to the chosen slot?">Send unlock command</button>
                </div>
            </form>
        </section>
    </c:if>

    <form class="filter" method="get" action="${ctx}/RemoteCommandController">
        <select name="status" aria-label="Status">
            <option value="">All statuses</option>
            <option value="AWAITING_EMAIL" ${status == 'AWAITING_EMAIL' ? 'selected' : ''}>Awaiting e-mail</option>
            <option value="PENDING" ${status == 'PENDING' ? 'selected' : ''}>Pending</option>
            <option value="SENT" ${status == 'SENT' ? 'selected' : ''}>Sent</option>
            <option value="DONE" ${status == 'DONE' ? 'selected' : ''}>Done</option>
            <option value="EXPIRED" ${status == 'EXPIRED' ? 'selected' : ''}>Expired</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/RemoteCommandController">Clear filters</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Slot</th><th>Reason</th><th>Requested by</th><th>Status</th><th>Created</th><th>Done</th></tr>
        <c:forEach var="cmd" items="${items}">
        <tr class="${cmd.status == 'PENDING' ? 'locked' : ''}">
            <td class="num">#${cmd.command_id}</td>
            <td><b><c:out value="${cmd.slot_code}"/></b></td>
            <td><c:out value="${cmd.reason}"/></td>
            <td><c:out value="${cmd.requested_by_name}"/></td>
            <td><ui:status value="${cmd.status}"/></td>
            <td><ui:dt value="${cmd.created_at}"/></td>
            <td><ui:dt value="${cmd.done_at}"/></td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">No commands yet.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/RemoteCommandController">
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
