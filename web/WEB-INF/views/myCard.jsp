<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="mycards"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>My cards</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>My cards</h2>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>Card UID</th><th class="c">Status</th><th>Issued</th><th class="c">Actions</th></tr>
        <c:forEach var="c" items="${items}">
        <tr class="${c.status == 'LOST' || c.status == 'BLOCKED' ? 'locked' : ''}">
            <td><code><c:out value="${c.cardUid}"/></code></td>
            <td class="c">${c.status}</td>
            <td>${c.issuedAt}</td>
            <td class="c">
                <c:choose>
                    <c:when test="${c.status == 'ACTIVE'}">
                        <a class="btn btn--sm" href="${ctx}/TopupController?cardId=${c.cardId}" style="margin-right:6px; padding:2px 8px; font-size:12px; background:#2e7d32; color:#fff; text-decoration:none; border-radius:3px;">💳 Nạp thẻ</a>
                        <form method="post" action="${ctx}/MyCardController" style="display:inline;" onsubmit="return confirm('Report this card as lost? It will be immediately deactivated.');">
                            <input type="hidden" name="action" value="reportLost">
                            <input type="hidden" name="cardId" value="${c.cardId}">
                            <button type="submit" class="link danger">Report lost</button>
                        </form>
                    </c:when>
                    <c:otherwise>
                        <span class="muted">${c.status}</span>
                    </c:otherwise>
                </c:choose>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="4" class="c">You do not have any cards assigned.</td></tr></c:if>
    </table>
    </div>

    <div style="margin-top:16px;">
        <a class="btn btn--primary" href="${ctx}/TopupController">💳 Nạp tiền vào thẻ ngay (Quét VietQR)</a>
    </div>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
