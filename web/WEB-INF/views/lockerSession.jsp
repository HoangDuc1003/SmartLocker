<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="sessions"/>
<%-- "Dữ liệu cảm biến". LockerSessionController sets items, total, page, pages, q, deviceId, from, to, sort, dir, error
     and devices. Read only: the sessions come from the boxes (POST /api/locker/batch) and the table is append-only. --%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Dữ liệu cảm biến · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <div>
            <h2>Dữ liệu cảm biến <span class="count">(${total})</span></h2>
            <p class="sub">Mỗi dòng là một lần mở và đóng ngăn mà hộp tủ gửi lên máy chủ (<code>POST /api/locker/batch</code>).
                Máy chủ kiểm tra dữ liệu rồi mới lưu; tải lại trang để thấy bản ghi mới.</p>
        </div>
    </div>

    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="filter" method="get" action="${ctx}/LockerSessionController">
        <input type="text" name="q" value="<c:out value='${q}'/>" maxlength="50"
               placeholder="Mã hộp, mã ngăn, cách mở, cảnh báo hoặc #số phiên" aria-label="Tìm kiếm">
        <select name="deviceId" aria-label="Hộp tủ">
            <option value="">Tất cả hộp tủ</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${deviceId == d.deviceId ? 'selected' : ''}><c:out value="${d.deviceCode}"/></option>
            </c:forEach>
        </select>
        <label class="filter__date">Từ ngày <input type="date" name="from" value="<c:out value='${from}'/>"></label>
        <label class="filter__date">Đến ngày <input type="date" name="to" value="<c:out value='${to}'/>"></label>
        <select name="sort" aria-label="Sắp xếp theo">
            <option value="measured" ${sort == 'measured' ? 'selected' : ''}>Sắp xếp: thời điểm đo</option>
            <option value="ingested" ${sort == 'ingested' ? 'selected' : ''}>Sắp xếp: lúc nhận</option>
            <option value="id" ${sort == 'id' ? 'selected' : ''}>Sắp xếp: số phiên</option>
            <option value="device" ${sort == 'device' ? 'selected' : ''}>Sắp xếp: hộp tủ</option>
            <option value="door" ${sort == 'door' ? 'selected' : ''}>Sắp xếp: thời gian mở cửa</option>
            <option value="weight" ${sort == 'weight' ? 'selected' : ''}>Sắp xếp: khối lượng</option>
            <option value="stay" ${sort == 'stay' ? 'selected' : ''}>Sắp xếp: thời gian gửi</option>
        </select>
        <select name="dir" aria-label="Chiều sắp xếp">
            <option value="desc" ${dir == 'desc' ? 'selected' : ''}>Giảm dần</option>
            <option value="asc" ${dir == 'asc' ? 'selected' : ''}>Tăng dần</option>
        </select>
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/LockerSessionController">Xóa lọc</a>
    </form>

    <%-- a header link sorts by its column; the same column again flips the direction --%>
    <c:set var="cols" value="id:Phiên,device:Hộp tủ,measured:Đo lúc,ingested:Nhận lúc,door:Mở cửa,weight:Khối lượng,stay:Thời gian gửi"/>
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
                <c:if test="${key == 'device'}"><th>Ngăn</th></c:if>
            </c:forEach>
            <th>Xác thực</th><th>Cách mở</th><th>Đánh giá</th>
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
                <td class="r num"><fmt:formatNumber value="${s.stay_min}" maxFractionDigits="0"/> phút</td>
                <td><span class="tag ${s.rfid_ok ? 'ok' : 'bad'}">${s.rfid_ok ? 'Hợp lệ' : 'Từ chối'}</span></td>
                <td><c:out value="${empty s.open_source ? '–' : s.open_source}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${not empty s.alert_label}">
                            <a class="tag bad" href="${ctx}/AlertController?id=${s.alert_id}"><c:out value="${s.alert_label}"/></a>
                        </c:when>
                        <c:when test="${not empty s.label}"><span class="tag info"><c:out value="${s.label}"/></span></c:when>
                        <c:otherwise><span class="tag ok">Không cảnh báo</span></c:otherwise>
                    </c:choose>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="11" class="empty">Không có bản ghi nào khớp bộ lọc.</td></tr></c:if>
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
