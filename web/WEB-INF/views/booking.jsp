<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<jsp:useBean id="now" class="java.util.Date"/>
<c:set var="activeNav" value="bookings"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>My bookings</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:16px;">
        <h2 style="margin:0;">My bookings</h2>
        <a class="btn btn--primary" href="${ctx}/TopupController">Add funds</a>
    </div>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>Bank</th><th>Slot</th><th>Plan</th><th>Payment</th><th>Status</th><th>Reserved</th><th>Due</th><th>Actions</th></tr>
        <c:forEach var="d" items="${items}">
        <c:set var="isOverdue" value="${d.status == 'ACTIVE' and not empty d.dueAt and d.dueAt.time lt now.time}"/>
        <tr class="${isOverdue ? 'locked' : ''}">
            <td><c:out value="${d.bankCode}"/></td>
            <td><c:out value="${d.slotCode}"/></td>
            <td><c:out value="${d.planName}"/></td>
            <td>
                <c:choose>
                    <c:when test="${d.paidAmount == 0}"><span class="tag">Free</span></c:when>
                    <c:when test="${d.status == 'CANCELLED' or d.status == 'NO_SHOW'}">
                        <span style="color:#667;">Refunded <fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND</span>
                    </c:when>
                    <c:otherwise>
                        <span style="background:#135d28; color:#ffffff; padding:2px 7px; border-radius:3px; font-weight:bold; font-size:12px; display:inline-block;">
                            Paid <fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND
                        </span>
                    </c:otherwise>
                </c:choose>
            </td>
            <td class="c">
                ${d.status}
                <c:if test="${isOverdue}"><span class="badge danger" style="color:var(--danger, #e74c3c);font-weight:bold;"> (OVERDUE)</span></c:if>
            </td>
            <td>${d.reservedAt}</td>
            <td>${d.dueAt}</td>
            <td class="ops">
                <c:choose>
                    <c:when test="${d.status == 'RESERVED'}">
                        <form method="post" action="${ctx}/BookingController" onsubmit="return confirm('Cancel this reservation?');" style="display:inline;">
                            <input type="hidden" name="action" value="cancel">
                            <input type="hidden" name="depositId" value="${d.depositId}">
                            <input type="hidden" name="back" value="list">
                            <button type="submit" class="link danger">Cancel</button>
                        </form>
                    </c:when>
                    <c:when test="${d.status == 'ACTIVE'}">
                        <c:choose>
                            <c:when test="${d.extendCount < 3}">
                                <form method="post" action="${ctx}/BookingController" style="display:inline-flex;gap:4px;align-items:center;">
                                    <input type="hidden" name="action" value="extend">
                                    <input type="hidden" name="depositId" value="${d.depositId}">
                                    <input type="hidden" name="back" value="list">
                                    <select name="minutes" style="padding:2px 4px;font-size:12px;">
                                        <option value="30">+30 min</option>
                                        <option value="60" selected>+60 min</option>
                                        <option value="120">+120 min</option>
                                    </select>
                                    <button type="submit" class="link">Extend (${d.extendCount}/3)</button>
                                </form>
                            </c:when>
                            <c:otherwise>
                                <span class="muted">Max extends reached (3/3)</span>
                            </c:otherwise>
                        </c:choose>
                    </c:when>
                    <c:otherwise>
                        <span class="muted">-</span>
                    </c:otherwise>
                </c:choose>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="c">You have no booking records.</td></tr></c:if>
    </table>
    </div>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
