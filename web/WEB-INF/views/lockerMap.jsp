<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="map"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Sơ đồ tủ · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/locker-map.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>

<%-- The page is an empty shell. js/locker-map.js reads these attributes, fetches data-api every 10 seconds and
     draws the areas, the cabinets and the slot panel. The forms of the panel post to the urls below. --%>
<div id="main">
<main id="lockerApp"
      data-api="${ctx}/api/locker-map"
      data-role="<c:out value='${not empty me ? me.roleName : \"END_USER\"}'/>"
      data-balance="${not empty me and not empty me.balance ? me.balance : 0}"
      data-booking-url="${ctx}/BookingController"
      data-mylocker-url="${ctx}/MyLockerController"
      data-topup-url="${ctx}/TopupController"
      data-command-url="${ctx}/RemoteCommandController"
      data-alert-url="${ctx}/AlertController"
      data-ticket-url="${ctx}/MaintenanceController?status=OPEN"
      data-slot-url="${ctx}/LockerSlotController">
    <p class="app-loading">Đang tải sơ đồ tủ…</p>
    <noscript><p class="app-loading">Sơ đồ tủ cần JavaScript. Hãy bật JavaScript trong trình duyệt.</p></noscript>
</main>
</div>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/locker-map.js"></script>
</body>
</html>
