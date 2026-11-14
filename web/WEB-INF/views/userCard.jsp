<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="cards"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>RFID cards · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>Issue a new card</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/UserCardController">
        <input type="hidden" name="action" value="issue">

        <label for="cardUid">Card UID (hex) <span class="req">*</span></label>
        <input type="text" id="cardUid" name="cardUid" value="<c:out value='${item.cardUid}'/>"
               required maxlength="32" pattern="[0-9A-Fa-f]{4,32}" title="4 to 32 hex characters"
               placeholder="04A1B2C3" aria-describedby="uidHint">
        <p class="hint" id="uidHint">4–32 characters 0–9, A–F, read from the card reader.</p>

        <label for="userId">User <span class="req">*</span></label>
        <select id="userId" name="userId" required>
            <option value="">Choose a user</option>
            <c:forEach var="u" items="${users}">
                <option value="${u.userId}" ${item.userId == u.userId ? 'selected' : ''}>
                    <c:out value="${u.username}"/> (<c:out value="${u.fullName}"/>)
                </option>
            </c:forEach>
        </select>

        <div class="actions">
            <button type="submit">Issue card</button>
            <a class="btn ghost" href="${ctx}/UserCardController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>RFID cards <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('USERCARD:WRITE')}">
            <a class="btn" href="${ctx}/UserCardController?action=new">Issue new card</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/UserCardController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Card UID or username" aria-label="Search">
        <select name="status" aria-label="Status">
            <option value="">All statuses</option>
            <option value="ACTIVE" ${status == 'ACTIVE' ? 'selected' : ''}>Active</option>
            <option value="BLOCKED" ${status == 'BLOCKED' ? 'selected' : ''}>Blocked</option>
            <option value="LOST" ${status == 'LOST' ? 'selected' : ''}>Reported lost</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/UserCardController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/UserCardController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Card UID</th><th>User</th><th>Status</th><th>Issued</th><th>Reported lost</th><th>Actions</th></tr>
        <c:forEach var="c" items="${items}">
        <tr class="${c.status == 'LOST' || c.status == 'BLOCKED' ? 'locked' : ''}">
            <td class="num">${c.cardId}</td>
            <td><code><c:out value="${c.cardUid}"/></code></td>
            <td><c:out value="${c.username}"/></td>
            <td><ui:status value="${c.status}"/></td>
            <td><ui:dt value="${c.issuedAt}"/></td>
            <td><ui:dt value="${c.lostAt}"/></td>
            <td class="ops">
                <c:if test="${perms.contains('USERCARD:WRITE')}">
                    <c:choose>
                        <c:when test="${c.status == 'ACTIVE'}">
                            <form method="post" action="${ctx}/UserCardController" data-confirm="Block this card?" data-confirm-danger>
                                <input type="hidden" name="action" value="block">
                                <input type="hidden" name="id" value="${c.cardId}">
                                <button type="submit" class="link danger">Block</button>
                            </form>
                        </c:when>
                        <c:when test="${c.status == 'BLOCKED'}">
                            <form method="post" action="${ctx}/UserCardController" data-confirm="Unblock this card?">
                                <input type="hidden" name="action" value="unblock">
                                <input type="hidden" name="id" value="${c.cardId}">
                                <button type="submit" class="link">Unblock</button>
                            </form>
                        </c:when>
                    </c:choose>
                    <c:if test="${c.status == 'BLOCKED' or c.status == 'LOST'}">
                        <form method="post" action="${ctx}/UserCardController" data-confirm="Replace this card with a new one?">
                            <input type="hidden" name="action" value="replace">
                            <input type="hidden" name="id" value="${c.cardId}">
                            <input type="text" name="newUid" placeholder="New UID" required pattern="[0-9A-Fa-f]{4,32}" aria-label="New card UID to replace card ${c.cardId}">
                            <button type="submit" class="btn--sm ghost">Replace card</button>
                        </form>
                    </c:if>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">No cards match the filters.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/UserCardController">
                        <c:param name="q" value="${q}"/>
                        <c:param name="status" value="${status}"/>
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
