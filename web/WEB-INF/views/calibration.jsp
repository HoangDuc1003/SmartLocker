<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="calibration"/>
<%--
  Calibration. Skeleton: the frame and the menu work, the rest is yours.
  Controller: CalibrationController
  Attributes it sets: list: items (Calibration), total, page, pages, deviceId, devices. form: item, isNew, devices, sensorTypes, error
  Filters: device
  Colour a row whose valid_until is in the past: that is what turns every session into SENSOR_FAULT.
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Calibration</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>Calibration</h2>

    <%-- TODO 1: the filter form (class="filter"), method get, keep the values with <c:out> --%>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Device</th><th>Sensor</th><th>Version</th><th>Offset</th><th>Scale</th><th>Valid until</th><th>Actions</th></tr>
        <%-- TODO 2: <c:forEach var="x" items="${items}"> one row per item, <c:out> for every text --%>
        <c:if test="${empty items}"><tr><td colspan="8" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <%-- TODO 3: the pager (class="pager") and, where the controller has a form mode, the form (class="form") --%>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
