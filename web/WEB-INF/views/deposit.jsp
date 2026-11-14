<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<%-- "now" as the UTC wall clock, the same frame as the timestamps read from the DB (it stores SYSUTCDATETIME) --%>
<% long nowMs = System.currentTimeMillis();
   pageContext.setAttribute("now", new java.util.Date(nowMs - java.util.TimeZone.getDefault().getOffset(nowMs))); %>
<c:set var="activeNav" value="deposits"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Bookings · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'New front-desk booking' : 'Edit booking'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/DepositController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.depositId}">

        <c:choose>
            <c:when test="${isNew}">
                <label for="userId">User <span class="req">*</span></label>
                <select id="userId" name="userId" required>
                    <option value="">Choose a user</option>
                    <c:forEach var="u" items="${users}">
                        <option value="${u.userId}" ${item.userId == u.userId ? 'selected' : ''}>
                            <c:out value="${u.username}"/> (<c:out value="${u.fullName}"/>)
                        </option>
                    </c:forEach>
                </select>

                <label for="slotId">Available slot <span class="req">*</span></label>
                <select id="slotId" name="slotId" required>
                    <option value="">Choose a slot</option>
                    <c:forEach var="s" items="${slots}">
                        <option value="${s.slotId}" ${item.slotId == s.slotId ? 'selected' : ''}>
                            <c:out value="${s.bankCode}"/> – <c:out value="${s.slotCode}"/> (size ${s.sizeCode})
                        </option>
                    </c:forEach>
                </select>

                <label for="planId">Storage plan <span class="req">*</span></label>
                <select id="planId" name="planId" required>
                    <option value="">Choose a plan</option>
                    <c:forEach var="p" items="${plans}">
                        <option value="${p.planId}" ${item.planId == p.planId ? 'selected' : ''}>
                            <c:out value="${p.planName}"/> (${p.durationMin} min – <fmt:formatNumber value="${p.price}" groupingUsed="true"/> VND)
                        </option>
                    </c:forEach>
                </select>
            </c:when>
            <c:otherwise>
                <label for="userShown">User</label>
                <input type="text" id="userShown" value="<c:out value='${item.username}'/>" readonly disabled>

                <label for="slotShown">Locker bank and slot</label>
                <input type="text" id="slotShown" value="<c:out value='${item.bankCode}'/> – <c:out value='${item.slotCode}'/>" readonly disabled>

                <label for="planId">Storage plan <span class="req">*</span></label>
                <select id="planId" name="planId" required>
                    <c:forEach var="p" items="${plans}">
                        <option value="${p.planId}" ${item.planId == p.planId ? 'selected' : ''}>
                            <c:out value="${p.planName}"/> (${p.durationMin} min – <fmt:formatNumber value="${p.price}" groupingUsed="true"/> VND)
                        </option>
                    </c:forEach>
                </select>
                <c:if test="${item.customMin != null}">
                    <p class="hint">Booking <c:out value="${item.planName}"/>: the due time follows the custom duration; the plan above only sets the grace period.</p>
                </c:if>

                <label for="status">Status <span class="req">*</span></label>
                <select id="status" name="status" required>
                    <option value="RESERVED" ${item.status == 'RESERVED' ? 'selected' : ''}>Reserved</option>
                    <option value="ACTIVE" ${item.status == 'ACTIVE' ? 'selected' : ''}>In use</option>
                    <option value="COMPLETED" ${item.status == 'COMPLETED' ? 'selected' : ''}>Completed</option>
                    <option value="NO_SHOW" ${item.status == 'NO_SHOW' ? 'selected' : ''}>No-show</option>
                    <option value="CANCELLED" ${item.status == 'CANCELLED' ? 'selected' : ''}>Cancelled</option>
                </select>

                <label for="dueAt">Due time</label>
                <input type="text" id="dueAt" name="dueAt" value="<ui:dt value="${item.dueAt}" input="true"/>" placeholder="YYYY-MM-DD HH:MM:SS" aria-describedby="dueHint">
                <p class="hint" id="dueHint">Format: year-month-day hour:minute:second, e.g. 2026-10-20 18:00:00.</p>
            </c:otherwise>
        </c:choose>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/DepositController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Bookings <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('DEPOSIT:WRITE')}">
            <a class="btn" href="${ctx}/DepositController?action=new">New front-desk booking</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/DepositController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Username or slot code" aria-label="Search">
        <select name="status" aria-label="Status">
            <option value="">All statuses</option>
            <option value="RESERVED" ${status == 'RESERVED' ? 'selected' : ''}>Reserved</option>
            <option value="ACTIVE" ${status == 'ACTIVE' ? 'selected' : ''}>In use</option>
            <option value="COMPLETED" ${status == 'COMPLETED' ? 'selected' : ''}>Completed</option>
            <option value="NO_SHOW" ${status == 'NO_SHOW' ? 'selected' : ''}>No-show</option>
            <option value="CANCELLED" ${status == 'CANCELLED' ? 'selected' : ''}>Cancelled</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/DepositController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/DepositController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>User</th><th>Locker bank</th><th>Slot</th><th>Plan</th><th>Status</th><th>Booked</th><th>Due</th><th>Overdue lock</th><th>Escalated</th><th>Actions</th></tr>
        <c:forEach var="d" items="${items}">
        <c:set var="isOverdue" value="${d.status == 'ACTIVE' and not empty d.dueAt and d.dueAt.time lt now.time}"/>
        <tr class="${isOverdue or (d.locked and d.status == 'ACTIVE') ? 'locked' : ''}">
            <td class="num">${d.depositId}</td>
            <td><c:out value="${d.username}"/></td>
            <td><c:out value="${d.bankCode}"/></td>
            <td><b><c:out value="${d.slotCode}"/></b></td>
            <td><c:out value="${d.planName}"/></td>
            <td>
                <ui:status value="${d.status}" kind="deposit"/>
                <c:if test="${isOverdue}"><ui:status value="OVERDUE"/></c:if>
            </td>
            <td><ui:dt value="${d.reservedAt}"/></td>
            <td><ui:dt value="${d.dueAt}"/></td>
            <%-- v3 D5: locked past due_at + grace (late fee charged so far), handed to the staff after 48 h --%>
            <td>
                <c:choose>
                    <c:when test="${d.locked}">
                        <ui:dt value="${d.lockedAt}"/>
                        <span class="muted">${d.overdueHours} h, <fmt:formatNumber value="${d.overdueFee}" groupingUsed="true"/> VND</span>
                    </c:when>
                    <c:otherwise><span class="muted">–</span></c:otherwise>
                </c:choose>
            </td>
            <td>
                <c:choose>
                    <c:when test="${not empty d.escalatedAt}"><span class="tag bad">Escalated</span> <ui:dt value="${d.escalatedAt}"/></c:when>
                    <c:otherwise><span class="muted">–</span></c:otherwise>
                </c:choose>
            </td>
            <td class="ops">
                <c:if test="${perms.contains('DEPOSIT:WRITE')}">
                    <a href="${ctx}/DepositController?action=edit&amp;id=${d.depositId}">Edit</a>
                    <c:if test="${d.status != 'RESERVED' and d.status != 'ACTIVE'}">
                        <form method="post" action="${ctx}/DepositController" data-confirm="Delete this booking record?" data-confirm-danger>
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${d.depositId}">
                            <button type="submit" class="link danger">Delete</button>
                        </form>
                    </c:if>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="11" class="empty">No bookings match the filters.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/DepositController">
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
