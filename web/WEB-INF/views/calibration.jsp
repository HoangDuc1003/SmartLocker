<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<jsp:useBean id="now" class="java.util.Date"/>
<c:set var="activeNav" value="calibration"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Sensor calibration · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add calibration version' : 'Edit calibration'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/CalibrationController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.calibId}">

        <c:choose>
            <c:when test="${isNew}">
                <label for="deviceId">Device <span class="req">*</span></label>
                <select id="deviceId" name="deviceId" required>
                    <option value="">Choose a device</option>
                    <c:forEach var="d" items="${devices}">
                        <option value="${d.deviceId}" ${item.deviceId == d.deviceId ? 'selected' : ''}>
                            <c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)
                        </option>
                    </c:forEach>
                </select>

                <label for="sensorTypeId">Sensor type <span class="req">*</span></label>
                <select id="sensorTypeId" name="sensorTypeId" required>
                    <option value="">Choose a sensor type</option>
                    <c:forEach var="st" items="${sensorTypes}">
                        <option value="${st[0]}" ${item.sensorTypeId == st[0] ? 'selected' : ''}><c:out value="${st[1]}"/></option>
                    </c:forEach>
                </select>
            </c:when>
            <c:otherwise>
                <label for="devShown">Device</label>
                <input type="text" id="devShown" value="<c:out value='${item.deviceCode}'/>" readonly disabled>

                <label for="sensorShown">Sensor</label>
                <input type="text" id="sensorShown" value="<c:out value='${item.sensorName}'/> (v${item.version})" readonly disabled>
            </c:otherwise>
        </c:choose>

        <label for="offsetVal">Offset <span class="req">*</span></label>
        <input type="number" id="offsetVal" name="offsetVal" value="${item.offsetVal}" step="any" required>

        <label for="scaleVal">Scale <span class="req">*</span></label>
        <input type="number" id="scaleVal" name="scaleVal" value="${item.scaleVal}" step="any" min="0.000001" required>

        <label for="validUntil">Valid until <span class="req">*</span></label>
        <input type="date" id="validUntil" name="validUntil" value="${item.validUntil}" required>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/CalibrationController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Sensor calibration <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('CALIBRATION:WRITE')}">
            <a class="btn" href="${ctx}/CalibrationController?action=new">Add calibration</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/CalibrationController">
        <select name="deviceId" aria-label="Device">
            <option value="">All devices</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${deviceId == d.deviceId ? 'selected' : ''}>
                    <c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)
                </option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/CalibrationController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/CalibrationController">
            <c:param name="action" value="export"/>
            <c:param name="deviceId" value="${deviceId}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Device</th><th>Sensor</th><th class="c">Version</th><th class="r">Offset</th><th class="r">Scale</th><th>Valid until</th><th>Actions</th></tr>
        <c:forEach var="c" items="${items}">
        <c:set var="isExpired" value="${not empty c.validUntil and c.validUntil.time lt now.time}"/>
        <tr class="${isExpired ? 'locked' : ''}">
            <td class="num">${c.calibId}</td>
            <td><c:out value="${c.deviceCode}"/></td>
            <td><c:out value="${c.sensorName}"/></td>
            <td class="c">v${c.version}</td>
            <td class="r num">${c.offsetVal}</td>
            <td class="r num">${c.scaleVal}</td>
            <td>
                <ui:dt value="${c.validUntil}" date="true"/>
                <c:if test="${isExpired}"><ui:status value="EXPIRED"/></c:if>
            </td>
            <td class="ops">
                <c:if test="${perms.contains('CALIBRATION:WRITE')}">
                    <a href="${ctx}/CalibrationController?action=edit&amp;id=${c.calibId}">Edit</a>
                    <form method="post" action="${ctx}/CalibrationController" data-confirm="Delete this calibration?" data-confirm-danger>
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${c.calibId}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="empty">No calibrations yet.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/CalibrationController">
                        <c:param name="deviceId" value="${deviceId}"/>
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
