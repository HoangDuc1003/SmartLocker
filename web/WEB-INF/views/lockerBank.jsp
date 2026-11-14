<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="banks"/>
<%--
  Banks. Controller: LockerBankController
  Attributes it sets: list: items (LockerBank), total, page, pages, q, areaId, areas. form: item, isNew, areas, devices, error
  A bank without a device is drawn for illustration only on the map.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Locker banks · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add locker bank' : 'Edit locker bank'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/LockerBankController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.bankId}">

        <label for="bankCode">Bank code <span class="req">*</span></label>
        <input type="text" id="bankCode" name="bankCode" value="<c:out value='${item.bankCode}'/>"
               required minlength="2" maxlength="20" pattern="[A-Za-z0-9_-]{2,20}"
               title="2 to 20 letters, digits, - or _" ${!isNew ? 'readonly' : ''}>

        <label for="name">Bank name <span class="req">*</span></label>
        <input type="text" id="name" name="name" value="<c:out value='${item.name}'/>" required minlength="1" maxlength="40">

        <label for="areaId">Area <span class="req">*</span></label>
        <select id="areaId" name="areaId" required>
            <option value="">Choose an area</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${item.areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> – <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>

        <label for="deviceId">Controller (ESP32)</label>
        <select id="deviceId" name="deviceId" aria-describedby="deviceHint">
            <option value="">None (illustration only)</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${item.deviceId == d.deviceId ? 'selected' : ''}><c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)</option>
            </c:forEach>
        </select>
        <p class="hint" id="deviceHint">A locker bank without a controller is only drawn on the map and cannot be unlocked.
            The real box, the banks it manages and the slot with a real lock are set with <code>sql/demo_box.sql</code>.</p>

        <label for="doorRows">Door rows (1–8) <span class="req">*</span></label>
        <input type="number" id="doorRows" name="doorRows" value="${item.doorRows > 0 ? item.doorRows : 4}" required min="1" max="8">

        <label for="status">Status <span class="req">*</span></label>
        <select id="status" name="status" required>
            <option value="ACTIVE" ${item.status == 'ACTIVE' ? 'selected' : ''}>Active</option>
            <option value="MAINTENANCE" ${item.status == 'MAINTENANCE' ? 'selected' : ''}>Maintenance</option>
        </select>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerBankController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Locker banks <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('LOCKERBANK:WRITE')}">
            <a class="btn" href="${ctx}/LockerBankController?action=new">Add locker bank</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/LockerBankController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Bank code or name" aria-label="Search">
        <select name="areaId" aria-label="Area">
            <option value="">All areas</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> – <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerBankController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/LockerBankController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="areaId" value="${areaId}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Code</th><th>Name</th><th>Area</th><th>Controller</th><th class="r">Rows</th><th class="r">Slots</th><th>Status</th><th>Actions</th></tr>
        <c:forEach var="x" items="${items}">
            <tr class="${x.status == 'MAINTENANCE' ? 'locked' : ''}">
                <td class="num">${x.bankId}</td>
                <td><b><c:out value="${x.bankCode}"/></b></td>
                <td><c:out value="${x.name}"/></td>
                <td><c:out value="${x.areaCode}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${x.deviceId != null && x.demoDevice}">
                            <c:out value="${x.deviceCode}"/> <span class="tag">Simulated</span>
                        </c:when>
                        <c:when test="${x.deviceId != null}">
                            <c:out value="${x.deviceCode}"/> <span class="tag info">Real box</span>
                            <div class="hint">
                                <c:choose>
                                    <c:when test="${empty x.physicalSlot}">Every slot unlocks for real</c:when>
                                    <c:when test="${x.physicalBank == x.bankCode}">Slot with a real lock: <b><c:out value="${x.physicalSlot}"/></b>; other slots only report OK</c:when>
                                    <c:otherwise>The slot with a real lock is in bank <c:out value="${x.physicalBank}"/> (<c:out value="${x.physicalSlot}"/>); slots here only report OK</c:otherwise>
                                </c:choose>
                            </div>
                        </c:when>
                        <c:otherwise><span class="tag">Illustration only</span></c:otherwise>
                    </c:choose>
                </td>
                <td class="r num">${x.doorRows}</td>
                <td class="r num">${x.slotCount}</td>
                <td><ui:status value="${x.status}"/></td>
                <td class="ops">
                    <c:if test="${perms.contains('LOCKERBANK:WRITE')}">
                        <a href="${ctx}/LockerBankController?action=edit&amp;id=${x.bankId}">Edit</a>
                        <form method="post" action="${ctx}/LockerBankController" data-confirm="Delete this locker bank?" data-confirm-danger>
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${x.bankId}">
                            <button type="submit" class="link danger">Delete</button>
                        </form>
                    </c:if>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="9" class="empty">No locker banks match the filters.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
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
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
