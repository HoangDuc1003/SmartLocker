<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="dashboard"/>
<%-- DashboardController sets (all optional, a missing one just shows 0):
       counts      Map: free, inUse, overdue, openAlerts, offlineDevices
       userCount, lockedCount, roleLabels (List of text), roleValues (List of numbers)
       devices     List of Device (deviceCode, location, status, lastSeenSec)
     The chart asks /api/dashboard itself and refreshes every 5 seconds. --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Dashboard</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>Dashboard</h2>

    <div class="cards">
        <div class="card"><div class="num">${empty counts.free ? 0 : counts.free}</div><div class="cap">Free slots</div></div>
        <div class="card"><div class="num">${empty counts.inUse ? 0 : counts.inUse}</div><div class="cap">Slots in use</div></div>
        <div class="card ${counts.overdue > 0 ? 'warn' : ''}"><div class="num">${empty counts.overdue ? 0 : counts.overdue}</div><div class="cap">Overdue slots</div></div>
        <div class="card ${counts.openAlerts > 0 ? 'warn' : ''}"><div class="num">${empty counts.openAlerts ? 0 : counts.openAlerts}</div><div class="cap">Open alerts</div></div>
        <div class="card ${counts.offlineDevices > 0 ? 'warn' : ''}"><div class="num">${empty counts.offlineDevices ? 0 : counts.offlineDevices}</div><div class="cap">Devices offline</div></div>
    </div>

    <h3>Live sessions</h3>
    <canvas id="liveChart" width="900" height="260"></canvas>
    <p class="hint">Blue: door open (s). Red: weight change (g). Refreshes every 5 seconds.</p>

    <h3>Devices</h3>
    <div class="tablewrap">
    <table class="grid">
        <tr><th>Code</th><th>Location</th><th class="c">Status</th><th class="c">Last seen</th></tr>
        <c:forEach var="d" items="${devices}">
        <tr class="${d.status == 'OFFLINE' ? 'locked' : ''}">
            <td><c:out value="${d.deviceCode}"/></td>
            <td><c:out value="${d.location}"/></td>
            <td class="c">${d.status}</td>
            <td class="c"><c:choose><c:when test="${empty d.lastSeenSec}">never</c:when><c:otherwise>${d.lastSeenSec} s ago</c:otherwise></c:choose></td>
        </tr>
        </c:forEach>
        <c:if test="${empty devices}"><tr><td colspan="4" class="c">No device yet</td></tr></c:if>
    </table>
    </div>

    <c:if test="${not empty roleLabels}">
        <h3>Users per role</h3>
        <canvas id="roleChart" width="720" height="240"></canvas>
    </c:if>
</div>

<script src="${ctx}/js/app.js"></script>
<script>
// a plain canvas line chart, no library: the exam machine may have no network
function drawSeries(ctx, values, width, height, color) {
    if (values.length < 2) { return; }
    var max = Math.max.apply(null, values), min = Math.min.apply(null, values), range = (max - min) || 1;
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (var i = 0; i < values.length; i++) {
        var x = i * width / (values.length - 1);
        var y = height - (values[i] - min) / range * (height - 20) - 10;
        if (i === 0) { ctx.moveTo(x, y); } else { ctx.lineTo(x, y); }
    }
    ctx.stroke();
}
function refreshChart() {
    fetch('${ctx}/api/dashboard?device=1', { credentials: 'same-origin' })
        .then(function (r) { return r.json(); })
        .then(function (rows) {
            var canvas = document.getElementById('liveChart'), ctx = canvas.getContext('2d');
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            drawSeries(ctx, rows.map(function (r) { return r.a; }), canvas.width, canvas.height, '#1f77b4');
            drawSeries(ctx, rows.map(function (r) { return r.b; }), canvas.width, canvas.height, '#d62728');
        })
        .catch(function () { /* the next refresh tries again */ });
}
refreshChart();
setInterval(refreshChart, 5000);
<c:if test="${not empty roleLabels}">
drawBars('roleChart', [<c:forEach var="l" items="${roleLabels}" varStatus="st">'<c:out value="${l}"/>'${st.last ? '' : ','}</c:forEach>],
                      [<c:forEach var="v" items="${roleValues}" varStatus="st">${v}${st.last ? '' : ','}</c:forEach>]);
</c:if>
</script>
</body>
</html>
