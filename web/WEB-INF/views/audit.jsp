<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="audit"/>
<%--
  Audit log. Skeleton: the frame and the menu work, the rest is yours.
  Controller: AuditController
  Attributes it sets: items (maps with audit_id, ts, actor, action, object_type, object_id, diff_json), total, page, pages, action, actions, integrity
  Filters: action
  A Verify chain button (GET action=verify) shows integrity: the first broken audit_id, or the text that the chain is intact.
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Audit log</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>Audit log</h2>

    <c:if test="${not empty integrity}">
        <div class="${integrityStatus == 'ok' ? 'flash' : 'error'}" style="margin-bottom:16px;">
            <c:out value="${integrity}"/>
        </div>
    </c:if>

    <form class="filter" method="get" action="${ctx}/AuditController">
        <select name="act">
            <option value="">-- All actions --</option>
            <c:forEach var="a" items="${actions}">
                <option value="${a}" ${action == a ? 'selected' : ''}><c:out value="${a}"/></option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/AuditController">Clear</a>
        <c:url var="verifyUrl" value="/AuditController">
            <c:param name="action" value="verify"/>
            <c:param name="act" value="${action}"/>
        </c:url>
        <a class="btn" href="${verifyUrl}">Verify chain</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Time (UTC)</th><th>Actor</th><th>Action</th><th>Object</th><th>Row</th><th>Detail</th></tr>
        <c:forEach var="x" items="${items}">
            <tr>
                <td>${x.audit_id}</td>
                <td>${x.ts}</td>
                <td><c:out value="${x.actor}"/></td>
                <td><b><c:out value="${x.action}"/></b></td>
                <td><c:out value="${x.object_type}"/></td>
                <td>${x.object_id}</td>
                <td style="font-family:monospace;font-size:12px;"><c:out value="${x.diff_json}"/></td>
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
                    <c:url var="pageUrl" value="/AuditController">
                        <c:param name="act" value="${action}"/>
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
