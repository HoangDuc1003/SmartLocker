<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="plans"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Storage plans</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add a storage plan' : 'Edit storage plan'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/StoragePlanController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.planId}">

        <label for="planName">Plan name *</label>
        <input type="text" id="planName" name="planName" value="<c:out value='${item.planName}'/>"
               required maxlength="40" placeholder="e.g. 2 Hours Standard">

        <label for="durationMin">Duration (minutes) *</label>
        <input type="number" id="durationMin" name="durationMin" value="${item.durationMin}"
               required min="1" max="1440">

        <label for="graceMin">Grace period (minutes) *</label>
        <input type="number" id="graceMin" name="graceMin" value="${item.graceMin}"
               required min="0" max="120">

        <label for="price">Price (VND) *</label>
        <input type="number" id="price" name="price" value="${item.price}"
               required min="0">

        <label>
            <input type="checkbox" name="isActive" value="true" ${item.active ? 'checked' : ''}>
            Active
        </label>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/StoragePlanController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Storage plans (${total})</h2>

    <div class="filter">
        <c:if test="${perms.contains('STORAGEPLAN:WRITE')}">
            <a class="btn" href="${ctx}/StoragePlanController?action=new">Add plan</a>
        </c:if>
        <a class="btn ghost" href="${ctx}/StoragePlanController?action=export">Export CSV</a>
    </div>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Name</th><th>Minutes</th><th>Grace (min)</th><th>Price</th><th>Status</th><th>Actions</th></tr>
        <c:forEach var="p" items="${items}">
        <tr class="${!p.active ? 'locked' : ''}">
            <td>${p.planId}</td>
            <td><c:out value="${p.planName}"/></td>
            <td>${p.durationMin}</td>
            <td>${p.graceMin}</td>
            <td>${p.price}</td>
            <td class="c">${p.active ? 'ACTIVE' : 'INACTIVE'}</td>
            <td class="ops">
                <c:if test="${perms.contains('STORAGEPLAN:WRITE')}">
                    <a href="${ctx}/StoragePlanController?action=edit&amp;id=${p.planId}">Edit</a>
                    <form method="post" action="${ctx}/StoragePlanController" onsubmit="return confirm('Delete this plan?');">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${p.planId}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>
</c:otherwise>

</c:choose>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
