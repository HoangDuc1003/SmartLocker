<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<jsp:useBean id="now" class="java.util.Date"/>
<c:set var="activeNav" value="deposits"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Deposits</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'New walk-in deposit' : 'Edit deposit'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/DepositController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.depositId}">

        <c:choose>
            <c:when test="${isNew}">
                <label for="userId">User *</label>
                <select id="userId" name="userId" required>
                    <option value="">-- Choose a user --</option>
                    <c:forEach var="u" items="${users}">
                        <option value="${u.userId}" ${item.userId == u.userId ? 'selected' : ''}>
                            <c:out value="${u.username}"/> (<c:out value="${u.fullName}"/>)
                        </option>
                    </c:forEach>
                </select>

                <label for="slotId">Available slot *</label>
                <select id="slotId" name="slotId" required>
                    <option value="">-- Choose a slot --</option>
                    <c:forEach var="s" items="${slots}">
                        <option value="${s.slotId}" ${item.slotId == s.slotId ? 'selected' : ''}>
                            <c:out value="${s.bankCode}"/> - <c:out value="${s.slotCode}"/> (${s.sizeCode})
                        </option>
                    </c:forEach>
                </select>

                <label for="planId">Storage plan *</label>
                <select id="planId" name="planId" required>
                    <option value="">-- Choose a plan --</option>
                    <c:forEach var="p" items="${plans}">
                        <option value="${p.planId}" ${item.planId == p.planId ? 'selected' : ''}>
                            <c:out value="${p.planName}"/> (${p.durationMin} min - ${p.price} VND)
                        </option>
                    </c:forEach>
                </select>
            </c:when>
            <c:otherwise>
                <label>User</label>
                <input type="text" value="<c:out value='${item.username}'/>" readonly disabled>

                <label>Locker &amp; Slot</label>
                <input type="text" value="<c:out value='${item.bankCode}'/> - <c:out value='${item.slotCode}'/>" readonly disabled>

                <label for="planId">Storage plan *</label>
                <select id="planId" name="planId" required>
                    <c:forEach var="p" items="${plans}">
                        <option value="${p.planId}" ${item.planId == p.planId ? 'selected' : ''}>
                            <c:out value="${p.planName}"/> (${p.durationMin} min - ${p.price} VND)
                        </option>
                    </c:forEach>
                </select>

                <label for="status">Status *</label>
                <select id="status" name="status" required>
                    <c:forEach var="st" items="RESERVED,ACTIVE,COMPLETED,NO_SHOW,CANCELLED">
                        <option value="${st}" ${item.status == st ? 'selected' : ''}>${st}</option>
                    </c:forEach>
                </select>

                <label for="dueAt">Due at</label>
                <input type="text" id="dueAt" name="dueAt" value="${item.dueAt}" placeholder="YYYY-MM-DD HH:MM:SS">
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
    <h2>Deposits (${total})</h2>

    <form class="filter" method="get" action="${ctx}/DepositController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Username or slot code">
        <select name="status">
            <option value="">-- All statuses --</option>
            <c:forEach var="st" items="RESERVED,ACTIVE,COMPLETED,NO_SHOW,CANCELLED">
                <option value="${st}" ${status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/DepositController">Clear</a>
        <c:if test="${perms.contains('DEPOSIT:WRITE')}">
            <a class="btn" href="${ctx}/DepositController?action=new">New walk-in</a>
        </c:if>
        <c:url var="exportUrl" value="/DepositController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>User</th><th>Bank</th><th>Slot</th><th>Plan</th><th>Status</th><th>Reserved</th><th>Due</th><th>Actions</th></tr>
        <c:forEach var="d" items="${items}">
        <c:set var="isOverdue" value="${d.status == 'ACTIVE' and not empty d.dueAt and d.dueAt.time lt now.time}"/>
        <tr class="${isOverdue ? 'locked' : ''}">
            <td>${d.depositId}</td>
            <td><c:out value="${d.username}"/></td>
            <td><c:out value="${d.bankCode}"/></td>
            <td><c:out value="${d.slotCode}"/></td>
            <td><c:out value="${d.planName}"/></td>
            <td class="c">
                ${d.status}
                <c:if test="${isOverdue}"><span class="badge danger" style="color:var(--danger, #e74c3c);font-weight:bold;"> (OVERDUE)</span></c:if>
            </td>
            <td>${d.reservedAt}</td>
            <td>${d.dueAt}</td>
            <td class="ops">
                <c:if test="${perms.contains('DEPOSIT:WRITE')}">
                    <a href="${ctx}/DepositController?action=edit&amp;id=${d.depositId}">Edit</a>
                    <c:if test="${d.status != 'RESERVED' and d.status != 'ACTIVE'}">
                        <form method="post" action="${ctx}/DepositController" onsubmit="return confirm('Delete this deposit record?');" style="display:inline;">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${d.depositId}">
                            <button type="submit" class="link danger">Delete</button>
                        </form>
                    </c:if>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="9" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
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
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
