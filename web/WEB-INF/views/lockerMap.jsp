<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="map"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Locker map</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/locker-map.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>

<%-- The page is an empty shell. js/locker-map.js reads these attributes, fetches data-api every 10 seconds and
     draws the areas, the cabinets and the slot panel. The forms of the panel post to the urls below. --%>
<main id="lockerApp" data-source="api"
      data-api="${ctx}/api/locker-map"
      data-role="<c:out value='${me.roleName}'/>"
      data-booking-url="${ctx}/BookingController"
      data-command-url="${ctx}/RemoteCommandController"
      data-alert-url="${ctx}/AlertController"
      data-ticket-url="${ctx}/MaintenanceController">
    <p class="app-loading">Loading locker map…</p>
    <noscript><p class="app-loading">The locker map needs JavaScript. Please enable it in your browser.</p></noscript>
</main>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/locker-map.js"></script>
</body>
</html>
