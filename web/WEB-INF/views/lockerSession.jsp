<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="sessions"/>
<%-- "Sensor data". LockerSessionController sets items, total, page, pages, q, deviceId, from, to, sort, dir, error
     and devices. Read only: the sessions come from the boxes (POST /api/locker/batch) and the table is append-only. --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Sensor data · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <div>
            <h2>Sensor data <span class="count">(${total})</span></h2>
            <p class="sub">Each row is one opening and closing of a slot that a locker box sent to the server (<code>POST /api/locker/batch</code>).
                The server checks the data before saving it; reload the page to see new records.</p>
        </div>
    </div>

    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="filter" method="get" action="${ctx}/LockerSessionController">
        <input type="text" name="q" value="<c:out value='${q}'/>" maxlength="50"
               placeholder="Box code, slot code, open method, alert or #session" aria-label="Search">
        <select name="deviceId" aria-label="Locker box">
            <option value="">All locker boxes</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${deviceId == d.deviceId ? 'selected' : ''}><c:out value="${d.deviceCode}"/></option>
            </c:forEach>
        </select>
        <label class="filter__date">From <input type="date" name="from" value="<c:out value='${from}'/>"></label>
        <label class="filter__date">To <input type="date" name="to" value="<c:out value='${to}'/>"></label>
        <select name="sort" aria-label="Sort by">
            <option value="measured" ${sort == 'measured' ? 'selected' : ''}>Sort: measured at</option>
            <option value="ingested" ${sort == 'ingested' ? 'selected' : ''}>Sort: received at</option>
            <option value="id" ${sort == 'id' ? 'selected' : ''}>Sort: session number</option>
            <option value="device" ${sort == 'device' ? 'selected' : ''}>Sort: locker box</option>
            <option value="door" ${sort == 'door' ? 'selected' : ''}>Sort: door-open time</option>
            <option value="weight" ${sort == 'weight' ? 'selected' : ''}>Sort: weight</option>
            <option value="stay" ${sort == 'stay' ? 'selected' : ''}>Sort: storage time</option>
        </select>
        <select name="dir" aria-label="Sort direction">
            <option value="desc" ${dir == 'desc' ? 'selected' : ''}>Descending</option>
            <option value="asc" ${dir == 'asc' ? 'selected' : ''}>Ascending</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerSessionController">Clear filters</a>
    </form>

    <%-- a header link sorts by its column; the same column again flips the direction --%>
    <c:set var="cols" value="id:Session,device:Locker box,measured:Measured,ingested:Received,door:Door open,weight:Weight,stay:Storage time"/>
    <div class="tablewrap">
    <table class="grid">
        <thead><tr>
            <c:forEach var="col" items="${cols}">
                <c:set var="key" value="${col.split(':')[0]}"/>
                <c:url var="sortUrl" value="/LockerSessionController">
                    <c:if test="${not empty q}"><c:param name="q" value="${q}"/></c:if>
                    <c:if test="${not empty deviceId}"><c:param name="deviceId" value="${deviceId}"/></c:if>
                    <c:if test="${not empty from}"><c:param name="from" value="${from}"/></c:if>
                    <c:if test="${not empty to}"><c:param name="to" value="${to}"/></c:if>
                    <c:param name="sort" value="${key}"/>
                    <c:param name="dir" value="${sort == key and dir == 'desc' ? 'asc' : 'desc'}"/>
                </c:url>
                <th class="${key == 'door' or key == 'weight' or key == 'stay' ? 'r' : ''}"
                    aria-sort="${sort == key ? (dir == 'desc' ? 'descending' : 'ascending') : 'none'}">
                    <a class="th-sort" href="${sortUrl}"><c:out value="${col.split(':')[1]}"/><c:if test="${sort == key}">
                        <span aria-hidden="true">${dir == 'desc' ? '↓' : '↑'}</span></c:if></a>
                </th>
                <c:if test="${key == 'device'}"><th>Slot</th></c:if>
            </c:forEach>
            <th>Auth</th><th>Open method</th><th>Assessment</th>
        </tr></thead>
        <tbody>
        <c:forEach var="s" items="${items}">
            <tr>
                <td class="num">#${s.session_id}</td>
                <td><c:out value="${s.device_code}"/></td>
                <td><b><c:out value="${empty s.slot_code ? '–' : s.slot_code}"/></b></td>
                <td><ui:dt value="${s.measured_at}"/></td>
                <td><ui:dt value="${s.ingested_at}"/></td>
                <td class="r num"><fmt:formatNumber value="${s.door_open_sec}" maxFractionDigits="1"/> s</td>
                <td class="r num"><fmt:formatNumber value="${s.weight_delta_g}" maxFractionDigits="0"/> g</td>
                <td class="r num"><fmt:formatNumber value="${s.stay_min}" maxFractionDigits="0"/> min</td>
                <td><span class="tag ${s.rfid_ok ? 'ok' : 'bad'}">${s.rfid_ok ? 'Valid' : 'Denied'}</span></td>
                <td><c:out value="${empty s.open_source ? '–' : s.open_source}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${not empty s.alert_label}">
                            <a class="tag bad" href="${ctx}/AlertController?id=${s.alert_id}"><c:out value="${s.alert_label}"/></a>
                        </c:when>
                        <c:when test="${not empty s.label}"><span class="tag info"><c:out value="${s.label}"/></span></c:when>
                        <c:otherwise><span class="tag ok">No alert</span></c:otherwise>
                    </c:choose>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="11" class="empty">No records match the filters.</td></tr></c:if>
        </tbody>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:when test="${p <= 2 or p > pages - 2 or (p >= page - 2 and p <= page + 2)}">
                    <c:url var="pageUrl" value="/LockerSessionController">
                        <c:if test="${not empty q}"><c:param name="q" value="${q}"/></c:if>
                        <c:if test="${not empty deviceId}"><c:param name="deviceId" value="${deviceId}"/></c:if>
                        <c:if test="${not empty from}"><c:param name="from" value="${from}"/></c:if>
                        <c:if test="${not empty to}"><c:param name="to" value="${to}"/></c:if>
                        <c:param name="sort" value="${sort}"/>
                        <c:param name="dir" value="${dir}"/>
                        <c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:when>
                <c:when test="${p == 3 or p == pages - 2}"><span aria-hidden="true">…</span></c:when>
            </c:choose>
        </c:forEach>
    </div>
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
