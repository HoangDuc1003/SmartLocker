<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="cards"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Cards</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>Issue a new card</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/UserCardController">
        <input type="hidden" name="action" value="issue">

        <label for="cardUid">Card UID (hex) *</label>
        <input type="text" id="cardUid" name="cardUid" value="<c:out value='${item.cardUid}'/>"
               required maxlength="32" pattern="[0-9A-Fa-f]{4,32}" title="4 to 32 hex characters"
               placeholder="e.g. 04A1B2C3">

        <label for="userId">User *</label>
        <select id="userId" name="userId" required>
            <option value="">-- Choose a user --</option>
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
    <h2>Cards (${total})</h2>

    <form class="filter" method="get" action="${ctx}/UserCardController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Card UID or username">
        <select name="status">
            <option value="">-- All statuses --</option>
            <c:forEach var="st" items="ACTIVE,BLOCKED,LOST">
                <option value="${st}" ${status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/UserCardController">Clear</a>
        <c:if test="${perms.contains('USERCARD:WRITE')}">
            <a class="btn" href="${ctx}/UserCardController?action=new">Issue card</a>
        </c:if>
        <c:url var="exportUrl" value="/UserCardController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Card UID</th><th>User</th><th>Status</th><th>Issued</th><th>Lost at</th><th>Actions</th></tr>
        <c:forEach var="c" items="${items}">
        <tr class="${c.status == 'LOST' || c.status == 'BLOCKED' ? 'locked' : ''}">
            <td>${c.cardId}</td>
            <td><code><c:out value="${c.cardUid}"/></code></td>
            <td><c:out value="${c.username}"/></td>
            <td class="c">${c.status}</td>
            <td>${c.issuedAt}</td>
            <td>${c.lostAt}</td>
            <td class="ops">
                <c:if test="${perms.contains('USERCARD:WRITE')}">
                    <c:choose>
                        <c:when test="${c.status == 'ACTIVE'}">
                            <form method="post" action="${ctx}/UserCardController" onsubmit="return confirm('Block this card?');" style="display:inline;">
                                <input type="hidden" name="action" value="block">
                                <input type="hidden" name="id" value="${c.cardId}">
                                <button type="submit" class="link danger">Block</button>
                            </form>
                        </c:when>
                        <c:when test="${c.status == 'BLOCKED'}">
                            <form method="post" action="${ctx}/UserCardController" onsubmit="return confirm('Unblock this card?');" style="display:inline;">
                                <input type="hidden" name="action" value="unblock">
                                <input type="hidden" name="id" value="${c.cardId}">
                                <button type="submit" class="link">Unblock</button>
                            </form>
                            <form method="post" action="${ctx}/UserCardController" style="display:inline-flex;gap:4px;align-items:center;" onsubmit="return confirm('Replace this card?');">
                                <input type="hidden" name="action" value="replace">
                                <input type="hidden" name="id" value="${c.cardId}">
                                <input type="text" name="newUid" placeholder="New UID" required pattern="[0-9A-Fa-f]{4,32}" style="width:90px;padding:2px 4px;font-size:12px;">
                                <button type="submit" class="link">Replace</button>
                            </form>
                        </c:when>
                        <c:when test="${c.status == 'LOST'}">
                            <form method="post" action="${ctx}/UserCardController" style="display:inline-flex;gap:4px;align-items:center;" onsubmit="return confirm('Replace this lost card?');">
                                <input type="hidden" name="action" value="replace">
                                <input type="hidden" name="id" value="${c.cardId}">
                                <input type="text" name="newUid" placeholder="New UID" required pattern="[0-9A-Fa-f]{4,32}" style="width:90px;padding:2px 4px;font-size:12px;">
                                <button type="submit" class="link">Replace</button>
                            </form>
                        </c:when>
                    </c:choose>
                </c:if>
            </td>
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
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
