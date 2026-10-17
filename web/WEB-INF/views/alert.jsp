<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="alerts"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Cảnh báo · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= DETAIL ================= --%>
<c:when test="${mode == 'detail'}">
    <div class="page-head">
        <div>
            <h2>Cảnh báo #${alert.alertId}: <c:out value="${alert.label}"/></h2>
        </div>
        <a class="btn ghost" href="${ctx}/AlertController">Quay lại danh sách</a>
    </div>

    <div class="grid-2">
        <section class="panel">
            <h3>Thông tin</h3>
            <dl class="kv">
                <dt>Trạng thái</dt><dd><ui:status value="${alert.status}"/></dd>
                <dt>Nguồn phát hiện</dt><dd><c:out value="${alert.source == 'ML' ? 'Mô hình học máy (ML)' : 'Luật (RULE)'}"/></dd>
                <dt>Thời điểm</dt><dd><ui:dt value="${alert.createdAt}"/></dd>
                <c:if test="${not empty alert.riskScore}">
                    <dt>Điểm rủi ro</dt><dd class="num"><c:out value="${alert.riskScore}"/></dd>
                </c:if>
                <dt>Thiết bị</dt>
                <dd>
                    <c:choose>
                        <c:when test="${not empty device}">
                            <b><c:out value="${device.deviceCode}"/></b> · <c:out value="${device.location}"/>
                            <ui:status value="${device.status}"/>
                        </c:when>
                        <c:otherwise>Thiết bị #${alert.deviceId}</c:otherwise>
                    </c:choose>
                </dd>
            </dl>
            <c:if test="${alert.status == 'OPEN' and perms.contains('ALERT:WRITE')}">
                <form method="post" action="${ctx}/AlertController" class="actions" data-confirm="Đánh dấu cảnh báo này là đã xử lý?">
                    <input type="hidden" name="action" value="resolve">
                    <input type="hidden" name="id" value="${alert.alertId}">
                    <button type="submit">Đánh dấu đã xử lý</button>
                </form>
            </c:if>
        </section>

        <c:if test="${not empty device and perms.contains('ALERT:WRITE')}">
            <section class="panel">
                <h3>Trạng thái thiết bị</h3>
                <p class="muted" style="margin-top:0">Sau khi kiểm tra hoặc sửa xong, kỹ thuật viên chỉnh lại trạng thái của bộ điều khiển
                    <b><c:out value="${device.deviceCode}"/></b>.</p>
                <form method="post" action="${ctx}/AlertController" class="actions">
                    <input type="hidden" name="action" value="device_status">
                    <input type="hidden" name="alertId" value="${alert.alertId}">
                    <input type="hidden" name="deviceId" value="${device.deviceId}">
                    <button type="submit" name="status" value="ACTIVE" class="btn--ok" ${device.status == 'ACTIVE' ? 'disabled' : ''}>Hoạt động lại</button>
                    <button type="submit" name="status" value="MAINTENANCE" class="ghost" ${device.status == 'MAINTENANCE' ? 'disabled' : ''}>Chuyển sang bảo trì</button>
                    <button type="submit" name="status" value="OFFLINE" class="btn--danger" ${device.status == 'OFFLINE' ? 'disabled' : ''}
                            data-confirm="Đánh dấu thiết bị là mất kết nối?" data-confirm-danger>Đánh dấu mất kết nối</button>
                </form>
            </section>
        </c:if>
    </div>

    <h3>Bằng chứng</h3>
    <div class="tablewrap">
    <table class="grid">
        <tr><th>Mục</th><th>Giá trị ghi nhận</th></tr>
        <c:forEach var="ev" items="${alert.evidence}">
            <tr>
                <td><b><c:out value="${ev[0]}"/></b></td>
                <td><code><c:out value="${ev[1]}"/></code></td>
            </tr>
        </c:forEach>
        <c:if test="${empty alert.evidence}">
            <tr><td colspan="2" class="empty">Không có bằng chứng đính kèm.</td></tr>
        </c:if>
    </table>
    </div>

    <c:if test="${not empty session}">
        <h3>Phiên mở tủ gây ra cảnh báo (#${session.sessionId})</h3>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Ngăn</th><th>Mã thẻ</th><th>Cách mở</th><th class="r">Mở cửa (giây)</th><th class="r">Thay đổi khối lượng (g)</th><th class="r">Số lần mở</th><th class="r">Thời gian gửi (phút)</th><th>Đo lúc</th></tr>
            <tr>
                <td><c:out value="${session.slotCode}"/></td>
                <td><code><c:out value="${session.cardUid}"/></code></td>
                <td><c:out value="${session.openSource}"/></td>
                <td class="r num"><c:out value="${session.doorOpenSec}"/></td>
                <td class="r num"><c:out value="${session.weightDeltaG}"/></td>
                <td class="r num"><c:out value="${session.unlockCount}"/></td>
                <td class="r num"><c:out value="${session.stayMin}"/></td>
                <td><ui:dt value="${session.measuredAt}"/></td>
            </tr>
        </table>
        </div>
    </c:if>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Cảnh báo <span class="count">(${total})</span></h2>
    </div>

    <form class="filter" method="get" action="${ctx}/AlertController">
        <select name="status" aria-label="Trạng thái">
            <option value="">Tất cả trạng thái</option>
            <option value="OPEN" ${status == 'OPEN' ? 'selected' : ''}>Chưa xử lý</option>
            <option value="RESOLVED" ${status == 'RESOLVED' ? 'selected' : ''}>Đã xử lý</option>
        </select>
        <input type="text" name="label" value="<c:out value='${label}'/>" placeholder="Lọc theo loại cảnh báo" aria-label="Loại cảnh báo">
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/AlertController">Xóa lọc</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Thời điểm</th><th>Thiết bị</th><th>Loại</th><th>Nguồn</th><th class="r">Rủi ro</th><th>Trạng thái</th><th>Thao tác</th></tr>
        <c:forEach var="a" items="${items}">
        <tr class="${a.status == 'OPEN' ? 'locked' : ''}">
            <td><a href="${ctx}/AlertController?id=${a.alertId}">#${a.alertId}</a></td>
            <td><ui:dt value="${a.createdAt}"/></td>
            <td>Thiết bị #${a.deviceId}</td>
            <td><b><c:out value="${a.label}"/></b></td>
            <td><c:out value="${a.source}"/></td>
            <td class="r num"><c:out value="${not empty a.riskScore ? a.riskScore : '–'}"/></td>
            <td><ui:status value="${a.status}"/></td>
            <td class="ops">
                <a href="${ctx}/AlertController?id=${a.alertId}">Chi tiết</a>
                <c:if test="${a.status == 'OPEN' and perms.contains('ALERT:WRITE')}">
                    <form method="post" action="${ctx}/AlertController" data-confirm="Đánh dấu cảnh báo này là đã xử lý?">
                        <input type="hidden" name="action" value="resolve">
                        <input type="hidden" name="id" value="${a.alertId}">
                        <button type="submit" class="link">Đã xử lý</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="empty">Không có cảnh báo nào.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/AlertController">
                        <c:param name="status" value="${status}"/>
                        <c:param name="label" value="${label}"/>
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
