<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<jsp:useBean id="now" class="java.util.Date"/>
<c:set var="activeNav" value="calibration"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Hiệu chuẩn cảm biến · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Thêm phiên bản hiệu chuẩn' : 'Sửa hiệu chuẩn'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/CalibrationController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.calibId}">

        <c:choose>
            <c:when test="${isNew}">
                <label for="deviceId">Thiết bị <span class="req">*</span></label>
                <select id="deviceId" name="deviceId" required>
                    <option value="">Chọn thiết bị</option>
                    <c:forEach var="d" items="${devices}">
                        <option value="${d.deviceId}" ${item.deviceId == d.deviceId ? 'selected' : ''}>
                            <c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)
                        </option>
                    </c:forEach>
                </select>

                <label for="sensorTypeId">Loại cảm biến <span class="req">*</span></label>
                <select id="sensorTypeId" name="sensorTypeId" required>
                    <option value="">Chọn loại cảm biến</option>
                    <c:forEach var="st" items="${sensorTypes}">
                        <option value="${st[0]}" ${item.sensorTypeId == st[0] ? 'selected' : ''}><c:out value="${st[1]}"/></option>
                    </c:forEach>
                </select>
            </c:when>
            <c:otherwise>
                <label for="devShown">Thiết bị</label>
                <input type="text" id="devShown" value="<c:out value='${item.deviceCode}'/>" readonly disabled>

                <label for="sensorShown">Cảm biến</label>
                <input type="text" id="sensorShown" value="<c:out value='${item.sensorName}'/> (v${item.version})" readonly disabled>
            </c:otherwise>
        </c:choose>

        <label for="offsetVal">Độ lệch (offset) <span class="req">*</span></label>
        <input type="number" id="offsetVal" name="offsetVal" value="${item.offsetVal}" step="any" required>

        <label for="scaleVal">Hệ số (scale) <span class="req">*</span></label>
        <input type="number" id="scaleVal" name="scaleVal" value="${item.scaleVal}" step="any" min="0.000001" required>

        <label for="validUntil">Hiệu lực đến <span class="req">*</span></label>
        <input type="date" id="validUntil" name="validUntil" value="${item.validUntil}" required>

        <div class="actions">
            <button type="submit">Lưu</button>
            <a class="btn ghost" href="${ctx}/CalibrationController">Hủy</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Hiệu chuẩn cảm biến <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('CALIBRATION:WRITE')}">
            <a class="btn" href="${ctx}/CalibrationController?action=new">Thêm hiệu chuẩn</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/CalibrationController">
        <select name="deviceId" aria-label="Thiết bị">
            <option value="">Tất cả thiết bị</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${deviceId == d.deviceId ? 'selected' : ''}>
                    <c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)
                </option>
            </c:forEach>
        </select>
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/CalibrationController">Xóa lọc</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/CalibrationController">
            <c:param name="action" value="export"/>
            <c:param name="deviceId" value="${deviceId}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Xuất CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Thiết bị</th><th>Cảm biến</th><th class="c">Phiên bản</th><th class="r">Độ lệch</th><th class="r">Hệ số</th><th>Hiệu lực đến</th><th>Thao tác</th></tr>
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
                    <a href="${ctx}/CalibrationController?action=edit&amp;id=${c.calibId}">Sửa</a>
                    <form method="post" action="${ctx}/CalibrationController" data-confirm="Xóa bản hiệu chuẩn này?" data-confirm-danger>
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${c.calibId}">
                        <button type="submit" class="link danger">Xóa</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="empty">Chưa có bản hiệu chuẩn nào.</td></tr></c:if>
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
