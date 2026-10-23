<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" language="java" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="dashboard"/>
<%-- Operations overview. DashboardController sets kpis, devices, roleLabels, roleValues, recentSessions for the first paint;
     js/dashboard.js then refreshes the numbers from /api/dashboard (the LockerMonitor snapshot, no DB query per poll). --%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Tổng quan · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap" data-api="${ctx}/api/dashboard" data-stats-api="${ctx}/api/dashboard/stats" data-alert-url="${ctx}/AlertController">

    <div class="page-head">
        <div>
            <h2>Tổng quan vận hành</h2>
            <p class="sub">Số liệu tự cập nhật từ máy chủ. <span id="db-time"></span></p>
        </div>
        <div class="sync">
            <span class="sync__state" id="db-state" data-state="idle" role="status" aria-live="polite">Đang kết nối…</span>
            <label class="visually-hidden" for="db-interval">Chu kỳ cập nhật</label>
            <select id="db-interval">
                <option value="5000" selected>Cập nhật mỗi 5 giây</option>
                <option value="15000">Mỗi 15 giây</option>
                <option value="60000">Mỗi 1 phút</option>
                <option value="0">Tạm dừng</option>
            </select>
            <button type="button" class="ghost" id="db-refresh">Làm mới</button>
        </div>
    </div>

    <%-- ===== KPI cards ===== --%>
    <c:set var="total" value="${not empty kpis ? kpis.totalSlots : 0}"/>
    <section class="cards" aria-label="Chỉ số chính">
        <div class="card">
            <span class="cap">Tổng số ngăn</span>
            <span class="num" id="k-total">${total}</span>
            <div class="meter" aria-hidden="true">
                <span class="m-ok" id="m-avail" style="width:${total > 0 ? kpis.availableSlots * 100 / total : 0}%"></span>
                <span class="m-use" id="m-occ" style="width:${total > 0 ? kpis.occupiedSlots * 100 / total : 0}%"></span>
                <span class="m-bad" id="m-fault" style="width:${total > 0 ? kpis.maintenanceOrFaultSlots * 100 / total : 0}%"></span>
            </div>
            <div class="legend">
                <span><i class="ok"></i>Trống <b id="k-avail">${not empty kpis ? kpis.availableSlots : 0}</b></span>
                <span><i class="use"></i>Đang dùng <b id="k-occ">${not empty kpis ? kpis.occupiedSlots : 0}</b></span>
                <span><i class="bad"></i>Lỗi/bảo trì <b id="k-fault">${not empty kpis ? kpis.maintenanceOrFaultSlots : 0}</b></span>
            </div>
        </div>
        <div class="card">
            <span class="cap">Tỉ lệ sử dụng</span>
            <span class="num" id="k-rate"><c:choose><c:when test="${total > 0}"><fmt:formatNumber value="${kpis.occupiedSlots * 100.0 / total}" maxFractionDigits="1"/>%</c:when><c:otherwise>0%</c:otherwise></c:choose></span>
            <div class="foot">Lượt gửi quá hạn: <b id="k-over">${not empty kpis ? kpis.overdueSessions : 0}</b></div>
        </div>
        <a class="card ${not empty kpis and kpis.activeAlerts > 0 ? 'warn' : ''}" id="c-alerts" href="${ctx}/AlertController?status=OPEN">
            <span class="cap">Cảnh báo chưa xử lý</span>
            <span class="num" id="k-alerts">${not empty kpis ? kpis.activeAlerts : 0}</span>
            <div class="foot">Xem danh sách cảnh báo</div>
        </a>
        <div class="card ${not empty kpis and kpis.offlineDevices > 0 ? 'warn' : ''}" id="c-offline">
            <span class="cap">Thiết bị mất kết nối</span>
            <span class="num" id="k-offline">${not empty kpis ? kpis.offlineDevices : 0}</span>
            <div class="foot" id="k-online">&nbsp;</div>
        </div>
        <div class="card ${not empty kpis and not kpis.auditChainValid ? 'warn' : 'ok'}" id="c-audit">
            <span class="cap">Chuỗi nhật ký kiểm toán</span>
            <span class="num" id="k-audit" style="font-size:20px">${not empty kpis and not kpis.auditChainValid ? 'Bị sửa đổi' : 'Toàn vẹn'}</span>
            <c:if test="${perms.contains('AUDIT:READ')}"><div class="foot"><a href="${ctx}/AuditController">Mở nhật ký</a></div></c:if>
        </div>
    </section>

    <%-- ===== Charts: js/dash-charts.js fills the .chart-body boxes from /api/dashboard and /api/dashboard/stats ===== --%>
    <section class="chart-grid" aria-label="Biểu đồ vận hành">
        <article class="chart-card">
            <h3>Tình trạng ngăn tủ</h3>
            <p class="sub">Toàn hệ thống, theo thời gian thực.</p>
            <div class="chart-body" id="ch-slots"><p class="chart-empty">Đang tải…</p></div>
        </article>
        <article class="chart-card chart-card--8">
            <h3>Mức dùng theo khu vực</h3>
            <p class="sub">Bấm tên khu để mở sơ đồ tủ của khu đó.</p>
            <div class="chart-body" id="ch-areas"><p class="chart-empty">Đang tải…</p></div>
        </article>
        <article class="chart-card">
            <h3>Thiết bị</h3>
            <p class="sub">Theo nhịp tim gần nhất của từng hộp.</p>
            <div class="chart-body" id="ch-devices"><p class="chart-empty">Đang tải…</p></div>
        </article>
        <article class="chart-card">
            <h3>Cảnh báo chưa xử lý</h3>
            <p class="sub">Chia theo loại. <a href="${ctx}/AlertController?status=OPEN">Xem danh sách</a></p>
            <div class="chart-body" id="ch-alerts"><p class="chart-empty">Đang tải…</p></div>
        </article>
        <article class="chart-card" id="card-revenue" hidden>
            <h3>Doanh thu gửi đồ</h3>
            <p class="sub" id="ch-revenue-meta">7 ngày gần nhất.</p>
            <div class="chart-body" id="ch-revenue"><p class="chart-empty">Đang tải…</p></div>
        </article>
        <article class="chart-card chart-card--6">
            <h3>Lượt đặt theo giờ</h3>
            <p class="sub" id="ch-hourly-meta">Giờ Việt Nam, hôm nay so với hôm qua.</p>
            <div class="chart-body" id="ch-hourly"><p class="chart-empty">Đang tải…</p></div>
        </article>
        <article class="chart-card chart-card--6">
            <h3>Khung giờ đông nhất</h3>
            <p class="sub">Lượt đặt theo thứ và giờ trong 4 tuần gần nhất.</p>
            <div class="chart-body" id="ch-heat"><p class="chart-empty">Đang tải…</p></div>
        </article>
    <section class="chart-card chart-card--12">
        <div class="panel-head">
            <h3>Cảm biến theo thiết bị</h3>
            <label class="visually-hidden" for="db-device">Thiết bị</label>
            <select id="db-device">
                <c:forEach var="d" items="${devices}">
                    <option value="${d.deviceId}"><c:out value="${d.deviceCode}"/></option>
                </c:forEach>
            </select>
        </div>
        <div class="seg" role="group" aria-label="Chỉ số hiển thị" style="margin-bottom:10px">
            <button type="button" data-mode="a" aria-pressed="true">Thời gian mở cửa (giây)</button>
            <button type="button" data-mode="b" aria-pressed="false">Thay đổi khối lượng (g)</button>
        </div>
        <div class="chart-box">
            <canvas id="db-chart" role="img" aria-label="Biểu đồ 50 phiên mở tủ gần nhất của thiết bị đã chọn"></canvas>
            <div class="chart-tip" id="db-tip" hidden></div>
        </div>
        <p class="hint" id="db-chart-meta" style="margin-top:8px"></p>
    </section>
    </section>

    <%-- ===== The tables, folded: the charts above answer the usual questions ===== --%>
    <details class="fold">
        <summary>Bảng chi tiết: khu vực, thiết bị, cảnh báo và phiên mở tủ</summary>
    <div class="grid-2">
        <section class="panel">
            <div class="panel-head">
                <h3>Theo khu vực</h3>
                <a href="${ctx}/LockerMapController">Mở sơ đồ tủ</a>
            </div>
            <div class="tablewrap">
                <table class="grid">
                    <thead><tr><th>Khu vực</th><th class="r">Tổng</th><th class="r">Đang dùng</th><th class="r">Trống</th><th class="r">Lỗi</th></tr></thead>
                    <tbody id="db-areas"><tr><td colspan="5" class="empty">Đang tải…</td></tr></tbody>
                </table>
            </div>
        </section>

        <section class="panel">
            <div class="panel-head">
                <h3>Thiết bị</h3>
                <span class="muted" id="db-online"></span>
            </div>
            <div class="tablewrap">
                <table class="grid">
                    <thead><tr><th>Thiết bị</th><th>Vị trí</th><th>Tình trạng</th><th class="r">Lần cuối kết nối</th></tr></thead>
                    <tbody id="db-devices">
                        <c:forEach var="d" items="${devices}">
                            <tr><td><b><c:out value="${d.deviceCode}"/></b></td><td><c:out value="${d.location}"/></td>
                                <td><ui:status value="${d.status}"/></td><td class="r muted">–</td></tr>
                        </c:forEach>
                        <c:if test="${empty devices}"><tr><td colspan="4" class="empty">Chưa có thiết bị nào.</td></tr></c:if>
                    </tbody>
                </table>
            </div>
        </section>
    </div>


    <div class="grid-2" style="margin-top:16px">
        <section class="panel">
            <div class="panel-head">
                <h3>Cảnh báo gần đây</h3>
                <a href="${ctx}/AlertController">Tất cả cảnh báo</a>
            </div>
            <div class="tablewrap">
                <table class="grid">
                    <thead><tr><th>Loại</th><th>Thiết bị</th><th class="r">Rủi ro</th><th>Thời điểm</th></tr></thead>
                    <tbody id="db-alerts"><tr><td colspan="4" class="empty">Đang tải…</td></tr></tbody>
                </table>
            </div>
        </section>
    </div>

    <section class="panel" style="margin-top:16px">
        <div class="panel-head">
            <h3>Phiên mở tủ gần đây</h3>
            <div class="seg" role="group" aria-label="Lọc phiên" id="db-session-filter">
                <button type="button" data-filter="all" aria-pressed="true">Tất cả</button>
                <button type="button" data-filter="door" aria-pressed="false">Mở lâu (&gt;10 giây)</button>
                <button type="button" data-filter="weight" aria-pressed="false">Có thay đổi đồ</button>
                <button type="button" data-filter="denied" aria-pressed="false">Thẻ bị từ chối</button>
            </div>
        </div>
        <div class="tablewrap">
            <table class="grid">
                <thead><tr><th>Phiên</th><th>Thiết bị · Ngăn</th><th>Mã thẻ</th><th class="r">Mở cửa</th><th class="r">Khối lượng</th><th>Thẻ</th><th>Cách mở</th><th>Đo lúc</th></tr></thead>
                <tbody id="db-sessions">
                    <c:forEach var="s" items="${recentSessions}">
                        <tr data-door="${s.door_open_sec}" data-weight="${s.weight_delta_g}" data-rfid="${s.rfid_ok}">
                            <td class="num">#${s.session_id}</td>
                            <td>Thiết bị #${s.device_id} · <b><c:out value="${not empty s.slot_code ? s.slot_code : s.slot_id}"/></b></td>
                            <td><code><c:out value="${not empty s.card_uid ? s.card_uid : '–'}"/></code></td>
                            <td class="r num"><fmt:formatNumber value="${s.door_open_sec}" maxFractionDigits="1"/> s</td>
                            <td class="r num"><fmt:formatNumber value="${s.weight_delta_g}" maxFractionDigits="0"/> g</td>
                            <td><span class="tag ${s.rfid_ok ? 'ok' : 'bad'}">${s.rfid_ok ? 'Hợp lệ' : 'Từ chối'}</span></td>
                            <td><c:out value="${not empty s.open_source ? s.open_source : 'CARD'}"/></td>
                            <td><ui:dt value="${s.measured_at}"/></td>
                        </tr>
                    </c:forEach>
                    <c:if test="${empty recentSessions}"><tr><td colspan="8" class="empty">Chưa có phiên mở tủ nào.</td></tr></c:if>
                </tbody>
            </table>
        </div>
    </section>

    </details>

    <c:if test="${not empty roleLabels}">
        <section class="panel" style="margin-top:16px">
            <h3>Người dùng theo vai trò</h3>
            <c:set var="roleMax" value="1"/>
            <c:forEach var="v" items="${roleValues}"><c:if test="${v > roleMax}"><c:set var="roleMax" value="${v}"/></c:if></c:forEach>
            <c:forEach var="label" items="${roleLabels}" varStatus="st">
                <div class="bar-row">
                    <span><c:out value="${label}"/></span>
                    <span class="bar-row__track"><span class="bar-row__fill" style="display:block;width:${roleValues[st.index] * 100 / roleMax}%"></span></span>
                    <span class="r num">${roleValues[st.index]}</span>
                </div>
            </c:forEach>
        </section>
    </c:if>
</main>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/dash-charts.js"></script>
<script src="${ctx}/js/dashboard.js"></script>
</body>
</html>
