<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- Public phone page /k/{device_code} (KioskController), the target of the QR printed on the box. No menu, no login.
     js/kiosk.js posts the PIN to /api/kiosk/unlock and shows the answer. --%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="robots" content="noindex">
    <title><c:out value="${empty device ? 'Không tìm thấy hộp tủ' : 'Mở tủ '.concat(device.device_code)}"/> · Smart Locker</title>
    <script src="${ctx}/js/theme.js"></script>
    <link rel="stylesheet" href="${ctx}/css/app.css">
</head>
<body>
<main class="kiosk" id="main">
    <div class="kiosk__box">
        <div class="kiosk__top">
            <span class="kiosk__brand">
                <span class="side-brand__mark"><svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg></span>
                Smart Locker
            </span>
            <button type="button" class="icon-btn theme-toggle" aria-label="Đổi nền sáng / tối">
                <svg class="ico ico-moon" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
                <svg class="ico ico-sun" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
            </button>
        </div>

        <c:choose>
            <c:when test="${empty device}">
                <div class="kiosk__card">
                    <h1>Không tìm thấy hộp tủ</h1>
                    <p class="sub">Không có hộp tủ nào mang mã <code><c:out value="${empty deviceCode ? '–' : deviceCode}"/></code>.</p>
                    <p>Hãy quét lại mã QR dán trên hộp tủ. Nếu vẫn lỗi, hãy báo nhân viên tại quầy.</p>
                </div>
            </c:when>
            <c:otherwise>
                <div class="kiosk__card">
                    <h1>Mở tủ <c:out value="${device.device_code}"/></h1>
                    <p class="sub">
                        <c:out value="${device.area_name}"/><c:if test="${not empty device.bank_code}"> · dãy <c:out value="${device.bank_code}"/></c:if><c:if test="${not empty device.location}"> · <c:out value="${device.location}"/></c:if>
                    </p>
                    <form id="kioskForm" data-api="${ctx}/api/kiosk/unlock" data-device="<c:out value='${device.device_code}'/>" novalidate>
                        <label for="pin">Mật mã 6 số</label>
                        <input id="pin" name="pin" class="kiosk__pin" type="text" inputmode="numeric" pattern="[0-9]{6}"
                               maxlength="6" autocomplete="one-time-code" required aria-describedby="pinHelp kioskResult">
                        <p class="hint" id="pinHelp">Xem mật mã ở mục Tủ của tôi trên web Smart Locker.</p>
                        <button type="submit" class="kiosk__submit" id="kioskSubmit">Mở tủ</button>
                    </form>
                    <p class="kiosk__result" id="kioskResult" role="status" aria-live="polite" hidden></p>
                </div>
                <p class="kiosk__help">Lần nhập đầu mở tủ để cất đồ, lần sau mở tủ để lấy đồ và kết thúc lượt.
                    Chốt tự đóng sau vài giây. Nhập sai 5 lần, trang này tạm khóa nhập 2 phút.</p>
            </c:otherwise>
        </c:choose>
    </div>
</main>
<c:if test="${not empty device}"><script src="${ctx}/js/kiosk.js"></script></c:if>
</body>
</html>
