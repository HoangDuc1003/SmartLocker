<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="topup"/>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<%-- ?panel=1: only the content, drawn by js/glass-panel.js as a glass popup over the users' map --%>
<c:set var="panel" value="${param.panel == '1'}"/>
<c:if test="${not panel}">
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Nạp tiền · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
</c:if>
<c:if test="${panel}">
<div class="glass-page">
<%@ include file="common/panel-flash.jspf" %>
</c:if>

<c:if test="${isStaff and not empty param.status}">
    <%-- Staff review of account top-ups: TopupController?status=... from the menu "Duyệt nạp tiền". --%>
    <div class="page-head">
        <div>
            <h2>Duyệt nạp tiền</h2>
            <p class="sub">Chỉ duyệt sau khi đã thấy tiền về tài khoản với đúng nội dung chuyển khoản.</p>
        </div>
    </div>
    <form class="filter" method="get" action="${ctx}/TopupController">
        <select name="status" aria-label="Trạng thái">
            <option value="ALL" ${status == 'ALL' or empty status ? 'selected' : ''}>Tất cả trạng thái</option>
            <option value="PENDING" ${status == 'PENDING' ? 'selected' : ''}>Chờ duyệt</option>
            <option value="APPROVED" ${status == 'APPROVED' ? 'selected' : ''}>Đã duyệt</option>
            <option value="REJECTED" ${status == 'REJECTED' ? 'selected' : ''}>Từ chối</option>
        </select>
        <button type="submit">Lọc</button>
    </form>

    <div class="tablewrap">
        <table class="grid">
            <tr><th>#</th><th>Người dùng</th><th class="r">Số tiền</th><th>Nội dung CK</th><th>Tạo lúc</th><th>Trạng thái</th><th>Thao tác</th></tr>
            <c:forEach var="req" items="${allRequests}">
                <tr class="${req.status == 'PENDING' ? 'locked' : ''}">
                    <td class="num">${req.requestId}</td>
                    <td><b><c:out value="${req.username}"/></b> <span class="muted"><c:out value="${req.fullName}"/></span></td>
                    <td class="r"><span class="money"><fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> đ</span></td>
                    <td><code><c:out value="${req.transferCode}"/></code></td>
                    <td><ui:dt value="${req.createdAt}"/></td>
                    <td><ui:status value="${req.status}"/></td>
                    <td class="ops">
                        <c:if test="${req.status == 'PENDING'}">
                            <form method="post" action="${ctx}/TopupController" data-confirm="Xác nhận đã nhận tiền và cộng vào ví người dùng?">
                                <input type="hidden" name="action" value="approve">
                                <input type="hidden" name="status" value="<c:out value="${status}"/>">
                                <input type="hidden" name="id" value="${req.requestId}">
                                <button type="submit" class="btn--sm btn--ok">Duyệt</button>
                            </form>
                            <form method="post" action="${ctx}/TopupController" data-confirm="Từ chối yêu cầu nạp tiền này?" data-confirm-danger>
                                <input type="hidden" name="action" value="reject">
                                <input type="hidden" name="status" value="<c:out value="${status}"/>">
                                <input type="hidden" name="id" value="${req.requestId}">
                                <button type="submit" class="link danger">Từ chối</button>
                            </form>
                        </c:if>
                        <c:if test="${req.status == 'APPROVED'}">
                            <span class="muted">Duyệt bởi <c:out value="${req.approvedByName}"/></span>
                        </c:if>
                    </td>
                </tr>
            </c:forEach>
            <c:if test="${empty allRequests}"><tr><td colspan="7" class="empty">Không có yêu cầu nạp tiền nào.</td></tr></c:if>
        </table>
    </div>
</c:if>

<c:if test="${not (isStaff and not empty param.status)}">
    <div class="page-head">
        <div>
            <h2 id="pageTitle">Nạp tiền vào ví</h2>
            <p class="sub">Quét mã VietQR để chuyển khoản. Số dư được cộng sau khi nhân viên xác nhận.</p>
        </div>
        <c:if test="${isStaff}"><a class="btn ghost" href="${ctx}/TopupController?status=PENDING">Duyệt nạp tiền</a></c:if>
    </div>

    <div class="grid-2">
        <section class="panel">
            <h3>Tạo yêu cầu nạp tiền</h3>
            <form method="post" action="${ctx}/TopupController" id="topupForm">
                <input type="hidden" name="action" value="create">

                <p class="muted" style="margin:0 0 8px" id="presetLabel">Chọn nhanh số tiền</p>
                <div class="presets" role="group" aria-labelledby="presetLabel">
                    <button type="button" class="btn ghost" data-amt="20000" aria-pressed="false">20.000 đ</button>
                    <button type="button" class="btn ghost" data-amt="50000" aria-pressed="true">50.000 đ</button>
                    <button type="button" class="btn ghost" data-amt="100000" aria-pressed="false">100.000 đ</button>
                    <button type="button" class="btn ghost" data-amt="200000" aria-pressed="false">200.000 đ</button>
                </div>

                <div class="field" style="margin-top:14px">
                    <label for="amount">Hoặc nhập số tiền (đồng)</label>
                    <input type="number" id="amount" name="amount" value="50000" min="1000" step="1" required inputmode="numeric">
                </div>
                <p class="hint" style="margin-top:6px">Tối thiểu 1.000 đ. Có thể nhập số lẻ, ví dụ 78888.</p>

                <div class="actions">
                    <button type="submit" class="btn--block">Tạo mã VietQR</button>
                </div>
            </form>
        </section>

        <section class="panel">
            <c:choose>
                <c:when test="${not empty currentQr}">
                    <h3>Quét để thanh toán</h3>
                    <img class="qr-img" src="<c:out value='${currentQr.qrUrl}'/>" alt="Mã VietQR chuyển khoản" width="280" height="280">
                    <dl class="kv">
                        <dt>Ngân hàng</dt><dd><c:out value="${bankName}"/></dd>
                        <dt>Số tài khoản</dt><dd><code><c:out value="${accountNumber}"/></code></dd>
                        <dt>Chủ tài khoản</dt><dd><c:out value="${accountName}"/></dd>
                        <dt>Số tiền</dt><dd class="money"><fmt:formatNumber value="${currentQr.amount}" groupingUsed="true"/> đ</dd>
                        <dt>Nội dung CK (bắt buộc)</dt><dd><code class="transfer-code"><c:out value="${currentQr.transferCode}"/></code></dd>
                        <dt>Trạng thái</dt>
                        <dd>
                            <ui:status value="${currentQr.status}"/>
                            <c:if test="${currentQr.status == 'REJECTED' and not empty currentQr.note}"><span class="muted"><c:out value="${currentQr.note}"/></span></c:if>
                        </dd>
                    </dl>
                </c:when>
                <c:otherwise>
                    <div class="qr-empty">
                        <div>
                            <p class="qr-empty-title">Chưa có mã QR</p>
                            <p class="qr-empty-text">Chọn số tiền rồi bấm <b>Tạo mã VietQR</b> để nhận thông tin chuyển khoản.</p>
                        </div>
                    </div>
                </c:otherwise>
            </c:choose>
        </section>
    </div>

    <h3>Lịch sử nạp tiền</h3>
    <div class="tablewrap">
        <table class="grid">
            <tr><th>#</th><th class="r">Số tiền</th><th>Nội dung CK</th><th>Tạo lúc</th><th>Trạng thái</th><th>Mã QR</th></tr>
            <c:forEach var="req" items="${myRequests}">
                <tr>
                    <td class="num">${req.requestId}</td>
                    <td class="r"><span class="money"><fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> đ</span></td>
                    <td><code><c:out value="${req.transferCode}"/></code></td>
                    <td><ui:dt value="${req.createdAt}"/></td>
                    <td><ui:status value="${req.status}"/></td>
                    <td class="ops"><a href="${ctx}/TopupController?id=${req.requestId}">Xem mã QR</a></td>
                </tr>
            </c:forEach>
            <c:if test="${empty myRequests}"><tr><td colspan="6" class="empty">Bạn chưa có yêu cầu nạp tiền nào.</td></tr></c:if>
        </table>
    </div>
</c:if>
<c:if test="${panel}">
</div>
</c:if>
<c:if test="${not panel}">
</main>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/user-pages.js"></script>
</body>
</html>
</c:if>
