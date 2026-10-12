<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<c:set var="activeNav" value="topup"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Nạp tiền vào thẻ - Smart Locker</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
    <style>
        .topup-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 16px; }
        @media (max-width: 800px) { .topup-grid { grid-template-columns: 1fr; } }
        .qr-card { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .qr-img { max-width: 300px; width: 100%; border-radius: 8px; border: 1px solid #ddd; margin: 12px 0; }
        .bank-info { text-align: left; background: #f9f9f9; padding: 12px 16px; border-radius: 6px; font-size: 14px; margin-top: 12px; }
        .bank-info dt { font-weight: bold; color: #555; }
        .bank-info dd { margin-bottom: 8px; color: #222; }
        .preset-amounts { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
        .preset-btn { background: #f0f4f8; border: 1px solid #c5d5e5; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 13px; font-weight: 500; }
        .preset-btn:hover { background: #e1ebf5; }
        .status-badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .status-pending { background: #fff3e0; color: #e65100; border: 1px solid #ffe0b2; }
        .status-approved { background: #e8f5e9; color: #2e7d32; border: 1px solid #c8e6c9; }
        .status-rejected { background: #ffebee; color: #c62828; border: 1px solid #ffcdd2; }
    </style>
</head>
<body>
<%@ include file="common/nav.jspf" %>

<div class="wrap">
    <h2>Nạp tiền vào thẻ Smart Locker</h2>
    <p class="sub">Quét mã VietQR để chuyển khoản. Admin sẽ xác nhận và thêm tiền vào thẻ/tài khoản của bạn ngay lập tức.</p>

    <c:if test="${isStaff}">
        <%-- ==================== ADMIN / OPERATOR VIEW: DUYỆT NẠP TIỀN ==================== --%>
        <div style="background: #eef6fc; border: 1px solid #bce; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
            <h3 style="margin-top: 0; color: #004b87;">Danh sách yêu cầu nạp tiền (Admin / Quản lý)</h3>
            <form class="filter" method="get" action="${ctx}/TopupController">
                <select name="status">
                    <option value="">-- Tất cả trạng thái --</option>
                    <option value="PENDING" ${status == 'PENDING' ? 'selected' : ''}>Chờ duyệt (PENDING)</option>
                    <option value="APPROVED" ${status == 'APPROVED' ? 'selected' : ''}>Đã duyệt (APPROVED)</option>
                    <option value="REJECTED" ${status == 'REJECTED' ? 'selected' : ''}>Đã từ chối (REJECTED)</option>
                </select>
                <button type="submit">Lọc</button>
                <a class="btn ghost" href="${ctx}/TopupController">Xóa lọc</a>
            </form>

            <div class="tablewrap" style="background:#fff; border-radius:6px;">
                <table class="grid">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Khách hàng</th>
                            <th>Thẻ RFID</th>
                            <th class="r">Số tiền</th>
                            <th>Mã chuyển khoản</th>
                            <th>Thời gian</th>
                            <th class="c">Trạng thái</th>
                            <th>Thao tác Admin</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="req" items="${allRequests}">
                            <tr>
                                <td>${req.requestId}</td>
                                <td><b><c:out value="${req.username}"/></b> <span class="muted">(<c:out value="${req.fullName}"/>)</span></td>
                                <td><c:out value="${req.cardUid != null ? req.cardUid : '-'}"/></td>
                                <td class="r" style="font-weight:bold; color:#2e7d32;">
                                    <fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> VND
                                </td>
                                <td><code><c:out value="${req.transferCode}"/></code></td>
                                <td style="font-size: 12px;"><fmt:formatDate value="${req.createdAt}" pattern="yyyy-MM-dd HH:mm"/></td>
                                <td class="c">
                                    <c:choose>
                                        <c:when test="${req.status == 'PENDING'}">
                                            <span class="status-badge status-pending">⏳ Chờ duyệt</span>
                                        </c:when>
                                        <c:when test="${req.status == 'APPROVED'}">
                                            <span class="status-badge status-approved">✓ Đã nạp</span>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="status-badge status-rejected">✗ Đã từ chối</span>
                                        </c:otherwise>
                                    </c:choose>
                                </td>
                                <td class="ops">
                                    <c:if test="${req.status == 'PENDING'}">
                                        <form method="post" action="${ctx}/TopupController" style="display:inline;" onsubmit="return confirm('Xác nhận đã nhận tiền và thêm <fmt:formatNumber value="${req.amount}"/> VND vào tài khoản ${req.username}?');">
                                            <input type="hidden" name="action" value="approve">
                                            <input type="hidden" name="id" value="${req.requestId}">
                                            <button type="submit" class="btn" style="background:#2e7d32; color:#fff; padding:4px 8px; font-size:12px; border:none; cursor:pointer;">✓ Xác nhận &amp; Thêm tiền</button>
                                        </form>
                                        <form method="post" action="${ctx}/TopupController" style="display:inline;" onsubmit="return confirm('Từ chối yêu cầu nạp tiền này?');">
                                            <input type="hidden" name="action" value="reject">
                                            <input type="hidden" name="id" value="${req.requestId}">
                                            <button type="submit" class="btn btn--danger" style="padding:4px 8px; font-size:12px;">Từ chối</button>
                                        </form>
                                    </c:if>
                                    <c:if test="${req.status == 'APPROVED'}">
                                        <span class="muted" style="font-size:11px;">Duyệt bởi <c:out value="${req.approvedByName}"/></span>
                                    </c:if>
                                </td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty allRequests}">
                            <tr><td colspan="8" class="c">Chưa có yêu cầu nạp tiền nào</td></tr>
                        </c:if>
                    </tbody>
                </table>
            </div>
        </div>
    </c:if>

    <%-- ==================== KHÁCH HÀNG VIEW: FORM NẠP & MÃ QR ==================== --%>
    <div class="topup-grid">
        <%-- Cột trái: Form tạo yêu cầu nạp tiền --%>
        <div class="box" style="background:#fff; border:1px solid #e0e0e0; border-radius:8px; padding:20px;">
            <h3 style="margin-top:0;">Tạo yêu cầu nạp tiền</h3>
            <form method="post" action="${ctx}/TopupController" id="topupForm">
                <input type="hidden" name="action" value="create">

                <c:if test="${not empty cards}">
                    <label for="cardId"><b>Chọn thẻ RFID cần nạp:</b></label>
                    <select id="cardId" name="cardId" style="width:100%; margin-bottom:16px; padding:8px;">
                        <c:forEach var="c" items="${cards}">
                            <option value="${c.cardId}">Thẻ UID: ${c.cardUid} (${c.status})</option>
                        </c:forEach>
                    </select>
                </c:if>

                <label><b>Chọn số tiền nạp nhanh:</b></label>
                <div class="preset-amounts">
                    <button type="button" class="preset-btn" onclick="setAmount(20000)">20,000 VND</button>
                    <button type="button" class="preset-btn" onclick="setAmount(50000)">50,000 VND</button>
                    <button type="button" class="preset-btn" onclick="setAmount(100000)">100,000 VND</button>
                    <button type="button" class="preset-btn" onclick="setAmount(200000)">200,000 VND</button>
                </div>

                <label for="amount"><b>Hoặc nhập số tiền (VND) *:</b></label>
                <input type="number" id="amount" name="amount" value="50000" min="1000" step="1000" required style="width:100%; margin-bottom:16px; padding:8px; font-size:16px; font-weight:bold;">

                <button type="submit" class="btn btn--primary btn--block" style="font-size:15px; padding:10px;">
                    💳 Tạo mã VietQR nạp tiền
                </button>
            </form>
        </div>

        <%-- Cột phải: Mã QR VietQR thanh toán --%>
        <div>
            <c:choose>
                <c:when test="${not empty currentQr}">
                    <div class="qr-card">
                        <h3 style="margin-top:0; color:#004b87;">Quét mã VietQR để thanh toán</h3>
                        <p style="font-size:13px; color:#666; margin-bottom:8px;">Mở ứng dụng Ngân hàng (MB, Vietcombank, Momo, v.v.) và quét mã QR:</p>

                        <img class="qr-img" src="${currentQr.qrUrl}" alt="VietQR Thanh Toán">

                        <div class="bank-info">
                            <dl style="margin:0;">
                                <dt>Ngân hàng:</dt>
                                <dd>MBBank (Ngân hàng Quân Đội)</dd>
                                <dt>Số tài khoản:</dt>
                                <dd><code>0981025559</code></dd>
                                <dt>Chủ tài khoản:</dt>
                                <dd>MB BANK</dd>
                                <dt>Số tiền:</dt>
                                <dd><strong style="color:#2e7d32; font-size:16px;"><fmt:formatNumber value="${currentQr.amount}" groupingUsed="true"/> VND</strong></dd>
                                <dt>Nội dung chuyển khoản (bắt buộc):</dt>
                                <dd><code style="background:#fff3e0; color:#d32f2f; font-weight:bold; font-size:14px; padding:2px 6px; border-radius:4px;">${currentQr.transferCode}</code></dd>
                                <dt>Trạng thái yêu cầu:</dt>
                                <dd>
                                    <c:choose>
                                        <c:when test="${currentQr.status == 'PENDING'}">
                                            <span class="status-badge status-pending">⏳ Chờ Admin xác nhận và thêm tiền</span>
                                        </c:when>
                                        <c:when test="${currentQr.status == 'APPROVED'}">
                                            <span class="status-badge status-approved">✓ Đã thêm tiền thành công vào thẻ!</span>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="status-badge status-rejected">✗ Đã từ chối (${currentQr.note})</span>
                                        </c:otherwise>
                                    </c:choose>
                                </dd>
                            </dl>
                        </div>
                    </div>
                </c:when>
                <c:otherwise>
                    <div class="qr-card" style="padding:40px 20px; color:#888;">
                        <p style="font-size:16px;">Vui lòng chọn số tiền và bấm <b>"Tạo mã VietQR nạp tiền"</b> ở bên trái để hiển thị mã QR.</p>
                    </div>
                </c:otherwise>
            </c:choose>
        </div>
    </div>

    <%-- ==================== LỊCH SỬ NẠP CỦA KHÁCH ==================== --%>
    <h3 style="margin-top:32px;">Lịch sử nạp tiền của bạn</h3>
    <div class="tablewrap" style="background:#fff; border-radius:6px;">
        <table class="grid">
            <thead>
                <tr>
                    <th>#</th>
                    <th>Thẻ RFID</th>
                    <th class="r">Số tiền</th>
                    <th>Nội dung CK</th>
                    <th>Thời gian</th>
                    <th class="c">Trạng thái</th>
                    <th>Xem lại QR</th>
                </tr>
            </thead>
            <tbody>
                <c:forEach var="req" items="${myRequests}">
                    <tr>
                        <td>${req.requestId}</td>
                        <td><c:out value="${req.cardUid != null ? req.cardUid : '-'}"/></td>
                        <td class="r" style="font-weight:bold; color:#2e7d32;">
                            <fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> VND
                        </td>
                        <td><code><c:out value="${req.transferCode}"/></code></td>
                        <td><fmt:formatDate value="${req.createdAt}" pattern="yyyy-MM-dd HH:mm"/></td>
                        <td class="c">
                            <c:choose>
                                <c:when test="${req.status == 'PENDING'}">
                                    <span class="status-badge status-pending">⏳ Chờ duyệt</span>
                                </c:when>
                                <c:when test="${req.status == 'APPROVED'}">
                                    <span class="status-badge status-approved">✓ Đã nạp</span>
                                </c:when>
                                <c:otherwise>
                                    <span class="status-badge status-rejected">✗ Từ chối</span>
                                </c:otherwise>
                            </c:choose>
                        </td>
                        <td>
                            <a class="btn ghost btn--sm" href="${ctx}/TopupController?id=${req.requestId}" style="padding:2px 8px; font-size:12px;">Xem mã QR</a>
                        </td>
                    </tr>
                </c:forEach>
                <c:if test="${empty myRequests}">
                    <tr><td colspan="7" class="c">Bạn chưa có yêu cầu nạp tiền nào</td></tr>
                </c:if>
            </tbody>
        </table>
    </div>
</div>

<script>
function setAmount(val) {
    document.getElementById('amount').value = val;
}
</script>
</body>
</html>
