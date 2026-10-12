<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="commands"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Remote commands</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>Remote commands (${total})</h2>

    <form class="filter" method="get" action="${ctx}/RemoteCommandController">
        <select name="status">
            <option value="">-- All statuses --</option>
            <c:forEach var="st" items="PENDING,SENT,DONE,EXPIRED">
                <option value="${st}" ${status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/RemoteCommandController">Clear</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Slot</th><th>Reason</th><th>Requested by</th><th>Status</th><th>Created</th><th>Used at</th></tr>
        <c:forEach var="cmd" items="${items}">
        <tr class="${cmd.status == 'PENDING' ? 'locked' : ''}">
            <td>#${cmd.command_id}</td>
            <td><c:out value="${cmd.slot_code}"/></td>
            <td><c:out value="${cmd.reason}"/></td>
            <td><c:out value="${cmd.requested_by_name}"/></td>
            <td class="c">
                <span class="badge ${cmd.status == 'DONE' ? '' : (cmd.status == 'PENDING' ? 'danger' : '')}">${cmd.status}</span>
            </td>
            <td>${cmd.created_at}</td>
            <td>${not empty cmd.done_at ? cmd.done_at : '-'}</td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
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
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
