<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="areas"/>
<%--
  Areas. Skeleton: the frame and the menu work, the rest is yours.
  Controller: LockerAreaController
  Attributes it sets: list: items (LockerArea), total, page, pages, q. form: item, isNew, error
  Filters: keyword, active only
  Same two modes as lockerSlot.jsp. A delete the database refuses shows its reason in the flash bar.
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Areas</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add area' : 'Edit area'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/LockerAreaController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.areaId}">

        <label for="areaCode">Area code *</label>
        <input type="text" id="areaCode" name="areaCode" value="<c:out value='${item.areaCode}'/>"
               required minlength="2" maxlength="16" pattern="[A-Za-z0-9]{2,16}"
               title="2 to 16 alphanumeric characters" ${!isNew ? 'readonly' : ''}>

        <label for="name">Area name *</label>
        <input type="text" id="name" name="name" value="<c:out value='${item.name}'/>"
               required minlength="2" maxlength="80">

        <label for="location">Location</label>
        <input type="text" id="location" name="location" value="<c:out value='${item.location}'/>"
               maxlength="120" placeholder="e.g. Building A, 1st floor">

        <label style="display:flex;align-items:center;gap:8px;cursor:pointer;margin-top:12px;">
            <input type="checkbox" name="active" value="true" ${item.active or isNew ? 'checked' : ''}>
            <span>Active (available for bookings and lockers)</span>
        </label>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerAreaController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Areas (${total})</h2>

    <form class="filter" method="get" action="${ctx}/LockerAreaController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Area code, name or location">
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerAreaController">Clear</a>
        <c:if test="${perms.contains('AREA:WRITE')}">
            <a class="btn" href="${ctx}/LockerAreaController?action=new">Add area</a>
        </c:if>
        <c:url var="exportUrl" value="/LockerAreaController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Code</th><th>Name</th><th>Location</th><th class="c">Slots</th><th class="c">Users</th><th class="c">Status</th><th>Actions</th></tr>
        <c:forEach var="x" items="${items}">
            <tr class="${not x.active ? 'locked' : ''}">
                <td>${x.areaId}</td>
                <td><b><c:out value="${x.areaCode}"/></b></td>
                <td><c:out value="${x.name}"/></td>
                <td><c:out value="${x.location}"/></td>
                <td class="c">${x.slotCount}</td>
                <td class="c">${x.userCount}</td>
                <td class="c">${x.active ? 'ACTIVE' : 'INACTIVE'}</td>
                <td class="ops">
                    <c:if test="${perms.contains('AREA:WRITE')}">
                        <a href="${ctx}/LockerAreaController?action=edit&amp;id=${x.areaId}">Edit</a>
                        <form method="post" action="${ctx}/LockerAreaController" style="display:inline;" onsubmit="return confirm('Delete this area?');">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${x.areaId}">
                            <button type="submit" class="link danger">Delete</button>
                        </form>
                    </c:if>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/LockerAreaController">
                        <c:param name="q" value="${q}"/>
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
