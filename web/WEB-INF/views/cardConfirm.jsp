<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- Public page /c/{token} (CardConfirmController), the target of the link in the card e-mail. No menu, no login.
     Opening it changes nothing; only the POST of a button decides. --%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="robots" content="noindex">
    <meta name="referrer" content="no-referrer">
    <title>Xác nhận mở tủ · Smart Locker</title>
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

        <div class="kiosk__card">
            <c:choose>
                <c:when test="${outcome == 'NOT_FOUND'}">
                    <h1>Liên kết không hợp lệ</h1>
                    <p class="sub">Không có yêu cầu mở tủ nào khớp với liên kết này.</p>
                    <p>Hãy quét lại thẻ tại hộp tủ và mở liên kết trong email mới nhất.</p>
                </c:when>
                <c:otherwise>
                    <h1><c:out value="${outcome == 'ASK' ? 'Xác nhận mở tủ' : 'Mở tủ bằng thẻ'}"/></h1>
                    <p class="sub">Ngăn <c:out value="${cmd.slot_code}"/> · dãy <c:out value="${cmd.bank_code}"/> · <c:out value="${cmd.area_name}"/><c:if test="${not empty cmd.location}"> · <c:out value="${cmd.location}"/></c:if></p>
                    <c:choose>
                        <c:when test="${outcome == 'ASK' or outcome == 'DEVICE_OFFLINE'}">
                            <c:if test="${outcome == 'DEVICE_OFFLINE'}">
                                <p class="kiosk__result is-wait" role="status">Hộp đang mất kết nối nên chưa mở được. Hãy thử lại sau ít giây.</p>
                            </c:if>
                            <p>Thẻ của bạn vừa được quét tại hộp <code><c:out value="${cmd.device_code}"/></code> để <c:out value="${action}"/>.</p>
                            <form method="post">
                                <button type="submit" class="kiosk__submit" name="decision" value="approve">Xác nhận mở tủ</button>
                                <button type="submit" class="kiosk__submit ghost" name="decision" value="reject">Không phải tôi</button>
                            </form>
                            <p class="kiosk__help">Liên kết dùng một lần và hết hiệu lực sau 5 phút kể từ lúc quét thẻ.</p>
                        </c:when>
                        <c:when test="${outcome == 'OK'}">
                            <p class="kiosk__result is-ok" role="status">Đã xác nhận. Hộp sẽ mở trong vài giây, hãy đứng trước ngăn <c:out value="${cmd.slot_code}"/>.</p>
                        </c:when>
                        <c:when test="${outcome == 'REJECTED'}">
                            <p class="kiosk__result is-bad" role="status">Đã hủy, tủ không mở. Nếu bạn không quét thẻ, có thể thẻ đang ở trong tay người khác: hãy báo nhân viên để khóa thẻ.</p>
                        </c:when>
                        <c:when test="${outcome == 'DONE_BEFORE'}">
                            <p class="kiosk__result is-ok" role="status">Yêu cầu này đã được xác nhận trước đó, không cần làm gì thêm.</p>
                        </c:when>
                        <c:otherwise>
                            <p class="kiosk__result is-bad" role="status">Liên kết đã hết hiệu lực. Hãy quét lại thẻ tại hộp tủ để nhận email mới.</p>
                        </c:otherwise>
                    </c:choose>
                </c:otherwise>
            </c:choose>
        </div>
    </div>
</main>
</body>
</html>
