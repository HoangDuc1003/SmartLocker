<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="banks"/>
<%--
  Banks. Skeleton: the frame and the menu work, the rest is yours.
  Controller: LockerBankController
  Attributes it sets: list: items (LockerBank), total, page, pages, q, areaId, areas. form: item, isNew, areas, devices, error
  Filters: keyword, area
  A bank without a device is drawn for illustration only on the map.
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Banks</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add bank' : 'Edit bank'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/LockerBankController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.bankId}">

        <label for="bankCode">Bank code *</label>
        <input type="text" id="bankCode" name="bankCode" value="<c:out value='${item.bankCode}'/>"
               required minlength="2" maxlength="20" pattern="[A-Za-z0-9_-]{2,20}"
               title="2 to 20 letters, digits, - or _" ${!isNew ? 'readonly' : ''}>

        <label for="name">Bank name *</label>
        <input type="text" id="name" name="name" value="<c:out value='${item.name}'/>"
               required minlength="1" maxlength="40">

        <label for="areaId">Area *</label>
        <select id="areaId" name="areaId" required>
            <option value="">-- Choose an area --</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${item.areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> - <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>

        <label for="deviceId">Device (ESP32 controller)</label>
        <select id="deviceId" name="deviceId">
            <option value="">-- None (Illustration only) --</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${item.deviceId == d.deviceId ? 'selected' : ''}><c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)</option>
            </c:forEach>
        </select>

        <label for="doorRows">Door rows (1-8) *</label>
        <input type="number" id="doorRows" name="doorRows" value="${item.doorRows > 0 ? item.doorRows : 4}"
               required min="1" max="8">

        <label for="status">Status *</label>
        <select id="status" name="status" required>
            <option value="ACTIVE" ${item.status == 'ACTIVE' ? 'selected' : ''}>ACTIVE</option>
            <option value="MAINTENANCE" ${item.status == 'MAINTENANCE' ? 'selected' : ''}>MAINTENANCE</option>
        </select>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerBankController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Banks (${total})</h2>

    <form class="filter" method="get" action="${ctx}/LockerBankController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Bank code or name">
        <select name="areaId">
            <option value="">-- All areas --</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> - <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerBankController">Clear</a>
        <c:if test="${perms.contains('LOCKERBANK:WRITE')}">
            <a class="btn" href="${ctx}/LockerBankController?action=new">Add bank</a>
        </c:if>
        <c:url var="exportUrl" value="/LockerBankController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="areaId" value="${areaId}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Code</th><th>Name</th><th>Area</th><th class="c">Device</th><th class="c">Door rows</th><th class="c">Slots</th><th class="c">Status</th><th>Actions</th></tr>
        <c:forEach var="x" items="${items}">
            <tr class="${x.status == 'MAINTENANCE' ? 'locked' : ''}">
                <td>${x.bankId}</td>
                <td><b><c:out value="${x.bankCode}"/></b></td>
                <td><c:out value="${x.name}"/></td>
                <td><c:out value="${x.areaCode}"/></td>
                <td class="c">${x.deviceId != null ? x.deviceId : '<span class="pill">None</span>'}</td>
                <td class="c">${x.doorRows}</td>
                <td class="c">${x.slotCount}</td>
                <td class="c">${x.status}</td>
                <td class="ops">
                    <c:if test="${perms.contains('LOCKERBANK:WRITE')}">
                        <a href="${ctx}/LockerBankController?action=edit&amp;id=${x.bankId}">Edit</a>
                        <form method="post" action="${ctx}/LockerBankController" style="display:inline;" onsubmit="return confirm('Delete this bank?');">
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${x.bankId}">
                            <button type="submit" class="link danger">Delete</button>
                        </form>
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
                    <c:url var="pageUrl" value="/LockerBankController">
                        <c:param name="q" value="${q}"/>
                        <c:param name="areaId" value="${areaId}"/>
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
