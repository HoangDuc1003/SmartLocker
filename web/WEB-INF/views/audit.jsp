<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="audit"/>
<%--
  Audit log. Controller: AuditController
  Attributes it sets: items (maps with audit_id, ts, actor, action, object_type, object_id, diff_json), total, page, pages, action, actions, integrity
  Filters: action. "Verify hash chain" (GET action=verify) shows integrity: the first broken audit_id, or the text that the chain is intact.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Audit log · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <div>
            <h2>Audit log <span class="count">(${total})</span></h2>
            <p class="sub">Every data change is appended to a SHA-256 hash chain; editing one row breaks the chain.</p>
        </div>
    </div>

    <c:if test="${not empty integrity}">
        <div class="${integrityStatus == 'ok' ? 'flash' : 'error'}" role="status"><c:out value="${integrity}"/></div>
    </c:if>

    <form class="filter" method="get" action="${ctx}/AuditController">
        <select name="act" aria-label="Action">
            <option value="">All actions</option>
            <c:forEach var="a" items="${actions}">
                <option value="<c:out value='${a}'/>" ${action == a ? 'selected' : ''}><c:out value="${a}"/></option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/AuditController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="verifyUrl" value="/AuditController">
            <c:param name="action" value="verify"/>
            <c:param name="act" value="${action}"/>
        </c:url>
        <a class="btn ghost" href="${verifyUrl}">Verify hash chain</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Time</th><th>Actor</th><th>Action</th><th>Object</th><th>ID</th><th>Details</th></tr>
        <c:forEach var="x" items="${items}">
            <tr>
                <td class="num">${x.audit_id}</td>
                <td><ui:dt value="${x.ts}"/></td>
                <td><c:out value="${x.actor}"/></td>
                <td><b><c:out value="${x.action}"/></b></td>
                <td><c:out value="${x.object_type}"/></td>
                <td class="num"><c:out value="${x.object_id}"/></td>
                <td class="mono" style="overflow-wrap:anywhere"><c:out value="${x.diff_json}"/></td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">No records yet.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
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
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
