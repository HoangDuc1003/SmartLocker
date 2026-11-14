<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="areas"/>
<%--
  Areas. Controller: LockerAreaController
  Attributes it sets: list: items (LockerArea), total, page, pages, q. form: item, isNew, error
  A delete the database refuses shows its reason in the flash bar.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Areas · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add area' : 'Edit area'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/LockerAreaController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.areaId}">

        <label for="areaCode">Area code <span class="req">*</span></label>
        <input type="text" id="areaCode" name="areaCode" value="<c:out value='${item.areaCode}'/>"
               required minlength="2" maxlength="16" pattern="[A-Za-z0-9]{2,16}"
               title="2 to 16 letters or digits" aria-describedby="codeHint" ${!isNew ? 'readonly' : ''}>
        <p class="hint" id="codeHint">2–16 plain letters (no accents) or digits. It cannot be changed after creation.</p>

        <label for="name">Area name <span class="req">*</span></label>
        <input type="text" id="name" name="name" value="<c:out value='${item.name}'/>" required minlength="2" maxlength="80">

        <label for="location">Location</label>
        <input type="text" id="location" name="location" value="<c:out value='${item.location}'/>"
               maxlength="120" placeholder="E.g. Building A, floor 1">

        <fieldset class="field-group">
            <legend>Position on the map</legend>
            <div class="form-row">
                <div>
                    <label for="latitude">Latitude</label>
                    <input type="text" id="latitude" name="latitude" inputmode="decimal" autocomplete="off"
                           value="<c:out value='${item.latitude}'/>" placeholder="10.841100" aria-describedby="coordHint">
                </div>
                <div>
                    <label for="longitude">Longitude</label>
                    <input type="text" id="longitude" name="longitude" inputmode="decimal" autocomplete="off"
                           value="<c:out value='${item.longitude}'/>" placeholder="106.809900" aria-describedby="coordHint">
                </div>
            </div>
            <p class="hint" id="coordHint">Open Google Maps, right-click the exact spot of the locker, then click the first line of numbers to copy "latitude, longitude". Leave empty to keep this area off the map for now.</p>
        </fieldset>

        <label class="check">
            <input type="checkbox" name="active" value="true" ${item.active or isNew ? 'checked' : ''}>
            Active (allows bookings and adding locker banks)
        </label>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerAreaController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Areas <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('AREA:WRITE')}">
            <a class="btn" href="${ctx}/LockerAreaController?action=new">Add area</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/LockerAreaController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Code, name or location" aria-label="Search">
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerAreaController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/LockerAreaController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Code</th><th>Name</th><th>Location</th><th class="r">Slots</th><th class="r">Users</th><th>Status</th><th>Actions</th></tr>
        <c:forEach var="x" items="${items}">
            <tr class="${not x.active ? 'locked' : ''}">
                <td class="num">${x.areaId}</td>
                <td><b><c:out value="${x.areaCode}"/></b></td>
                <td><c:out value="${x.name}"/></td>
                <td><c:out value="${x.location}"/></td>
                <td class="r num">${x.slotCount}</td>
                <td class="r num">${x.userCount}</td>
                <td><ui:status value="${x.active ? 'ACTIVE' : 'INACTIVE'}"/></td>
                <td class="ops">
                    <c:if test="${perms.contains('AREA:WRITE')}">
                        <a href="${ctx}/LockerAreaController?action=edit&amp;id=${x.areaId}">Edit</a>
                        <form method="post" action="${ctx}/LockerAreaController" data-confirm="Delete this area?" data-confirm-danger>
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${x.areaId}">
                            <button type="submit" class="link danger">Delete</button>
                        </form>
                    </c:if>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="empty">No areas match the filters.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
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
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
