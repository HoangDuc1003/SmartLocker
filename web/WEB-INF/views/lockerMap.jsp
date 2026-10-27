<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<c:set var="activeNav" value="map"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Sơ đồ tủ · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/js/vendor/leaflet/leaflet.css">
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/locker-map.css">
</head>
<body class="map-page">
<%-- the map page has no sidebar: the menu is the floating tab bar --%>
<%@ include file="common/nav-floating.jspf" %>

<%-- edge refraction of the glass islands (css/locker-map.css .glass--refract, Chromium only) --%>
<svg class="visually-hidden" width="0" height="0" aria-hidden="true" focusable="false">
    <filter id="glass-refract" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB">
        <feTurbulence type="fractalNoise" baseFrequency="0.006 0.01" numOctaves="2" seed="7" result="noise"/>
        <feGaussianBlur in="noise" stdDeviation="2" result="soft"/>
        <feDisplacementMap in="SourceGraphic" in2="soft" scale="22" xChannelSelector="R" yChannelSelector="G"/>
    </filter>
</svg>

<%-- The page is a full-screen map with glass islands on top. js/locker-map.js reads the data-* attributes,
     fetches data-api every 10 seconds and fills the area sheet, the slot card and the pins (js/area-map.js).
     The forms of the slot card post to the urls below. --%>
<div id="main">
<main id="lockerApp" class="map-app"
      data-ctx="${ctx}"
      data-api="${ctx}/api/locker-map"
      data-role="<c:out value='${not empty me ? me.roleName : \"GUEST\"}'/>"
      data-balance="${not empty me and not empty me.balance ? me.balance : 0}"
      data-login-url="${ctx}/LoginController"
      data-booking-url="${ctx}/BookingController"
      data-mylocker-url="${ctx}/MyLockerController"
      data-topup-url="${ctx}/TopupController">

    <div class="map-canvas" data-ref="mapCanvas" role="region" aria-label="Bản đồ các khu vực tủ"></div>
    <p class="map-notice glass glass--pill" data-ref="mapNotice" role="status" hidden>Không tải được nền bản đồ (cần Internet). Các khu vẫn nằm đúng vị trí.</p>

    <div class="map-left">
        <div class="search-pill glass glass--pill glass--refract">
            <svg class="ico" aria-hidden="true"><use href="#i-search"/></svg>
            <label for="mapSearch" class="visually-hidden">Tìm khu vực hoặc ngăn</label>
            <input id="mapSearch" type="search" data-ref="search" placeholder="Tìm khu vực hoặc ngăn, ví dụ A01" autocomplete="off" enterkeyhint="search">
            <%-- swapped by js/locker-map.js after a sign-in in the popup --%>
            <div class="acct" id="glassAccount">
                <c:choose>
                    <c:when test="${not empty me}">
                        <c:set var="meName" value="${not empty me.fullName ? me.fullName : me.username}"/>
                        <button type="button" class="acct__btn lg-hover" data-pop aria-expanded="false" aria-controls="acctMenu"
                                aria-label="Tài khoản <c:out value='${meName}'/>">
                            <span class="avatar" aria-hidden="true"><c:out value="${meName.substring(0, 1).toUpperCase()}"/></span>
                        </button>
                        <div class="pop pop--down glass glass--stack" id="acctMenu" hidden>
                            <p class="pop__who"><b><c:out value="${meName}"/></b><span><c:out value="${roleLabel}"/></span></p>
                            <c:if test="${not empty me.balance}">
                                <a class="pop__link lg-hover" href="${ctx}/TopupController">
                                    <svg class="ico" aria-hidden="true"><use href="#i-wallet"/></svg>Số dư
                                    <b data-balance-text><fmt:formatNumber value="${me.balance}" type="number" groupingUsed="true"/> đ</b></a>
                            </c:if>
                            <a class="pop__link lg-hover" href="${ctx}/LogoutController">
                                <svg class="ico" aria-hidden="true"><use href="#i-logout"/></svg>Đăng xuất</a>
                        </div>
                    </c:when>
                    <c:otherwise>
                        <a class="acct__btn lg-hover" href="${ctx}/LoginController" data-auth-open="login" aria-label="Đăng nhập">
                            <span class="avatar avatar--guest" aria-hidden="true"><svg class="ico"><use href="#i-user"/></svg></span></a>
                    </c:otherwise>
                </c:choose>
            </div>
        </div>

        <section class="sheet glass glass--sheet glass--dense" data-ref="sheet" aria-label="Khu vực tủ">
            <button type="button" class="sheet__grab" data-sheet-grab tabindex="-1" aria-hidden="true"><span></span></button>
            <div class="sheet__body" data-ref="sheetBody">
                <div data-ref="listView">
                    <div class="sheet-head"><h2 class="sheet-title">Khu vực</h2></div>
                    <div class="near" data-ref="near"></div>
                    <div class="area-list" data-ref="areas"><p class="sheet-empty">Đang tải sơ đồ tủ…</p></div>
                </div>
                <div data-ref="detailView" hidden>
                    <div class="sheet-head">
                        <div>
                            <h2 class="sheet-title" id="areaTitle" data-ref="title">Khu vực</h2>
                            <p class="sheet-sub" data-ref="sub"></p>
                        </div>
                        <button type="button" class="round-btn lg-hover" data-sheet-list aria-label="Đóng, về danh sách khu vực">
                            <svg class="ico" aria-hidden="true"><use href="#i-close"/></svg></button>
                    </div>
                    <div class="quick" data-ref="quick"></div>
                    <div class="status-chips" role="group" aria-label="Lọc ngăn theo trạng thái" data-ref="chips"></div>
                    <div class="bank-list" data-ref="banks"></div>
                </div>
                <div data-ref="sheetSlot"></div>
            </div>
            <div class="sheet__foot">
                <span class="sheet__sync" data-ref="sync" aria-live="polite">Đang tải</span>
                <span class="sheet__osm">© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a></span>
                <button type="button" class="sheet__refresh lg-hover" data-refresh aria-label="Làm mới ngay" title="Làm mới ngay">
                    <svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M19 12a7 7 0 1 1-2.05-4.95"/><path d="M19 4.5V8h-3.5"/></svg></button>
            </div>
            <noscript><p class="sheet-empty">Sơ đồ tủ cần JavaScript. Hãy bật JavaScript trong trình duyệt.</p></noscript>
        </section>
    </div>

    <div class="map-right">
        <div class="balance-slot" id="glassBalance"><c:if test="${not empty me and not empty me.balance}">
            <a class="balance-pill lg-hover glass glass--pill glass--refract" href="${ctx}/TopupController" aria-label="Số dư ví, nạp tiền">
                <svg class="ico" aria-hidden="true"><use href="#i-wallet"/></svg>
                <b data-balance-text><fmt:formatNumber value="${me.balance}" type="number" groupingUsed="true"/> đ</b>
                <span class="balance-pill__cta">Nạp tiền</span></a>
        </c:if></div>
        <div class="ctl-stack glass glass--stack glass--refract">
            <button type="button" class="ctl lg-hover" data-map-me aria-label="Vị trí của tôi" title="Vị trí của tôi">
                <svg class="ico" aria-hidden="true"><use href="#i-locate"/></svg></button>
            <button type="button" class="ctl lg-hover" data-map-fit aria-label="Xem tất cả khu vực" title="Xem tất cả khu vực">
                <svg class="ico" aria-hidden="true"><use href="#i-fit"/></svg></button>
            <button type="button" class="ctl lg-hover theme-toggle" aria-label="Đổi nền sáng / tối" title="Đổi nền sáng / tối">
                <svg class="ico ico-moon" aria-hidden="true"><use href="#i-moon"/></svg>
                <svg class="ico ico-sun" aria-hidden="true"><use href="#i-sun"/></svg></button>
        </div>
        <div class="ctl-stack ctl-stack--zoom glass glass--stack glass--refract">
            <button type="button" class="ctl lg-hover" data-map-zoom="in" aria-label="Phóng to" title="Phóng to">
                <svg class="ico" aria-hidden="true"><use href="#i-plus"/></svg></button>
            <button type="button" class="ctl lg-hover" data-map-zoom="out" aria-label="Thu nhỏ" title="Thu nhỏ">
                <svg class="ico" aria-hidden="true"><use href="#i-minus"/></svg></button>
        </div>
    </div>

    <aside class="slot-card glass glass--sheet glass--dense" data-ref="panel" aria-labelledby="panelTitle" tabindex="-1" hidden></aside>

    <ul class="map-legend glass glass--pill" aria-label="Chú thích trạng thái ngăn">
        <li><span class="lg st-AVAILABLE" aria-hidden="true"></span>Trống</li>
        <li><span class="lg st-RESERVED" aria-hidden="true"></span>Đã đặt</li>
        <li><span class="lg st-OCCUPIED" aria-hidden="true"></span>Đang dùng</li>
        <li><span class="lg st-OVERDUE" aria-hidden="true"></span>Quá hạn</li>
    </ul>
</main>

<%-- "Tủ của tôi" and "Nạp tiền" open here as glass popups (js/glass-panel.js draws MyLockerController / TopupController
     with ?panel=1). Not modal: the tab bar under it stays usable. --%>
<dialog class="glass-dlg glass glass--sheet glass--dense" id="glassPanel" aria-labelledby="pageTitle">
    <button type="button" class="round-btn lg-hover glass-dlg__close" data-panel-close aria-label="Đóng, về sơ đồ tủ">
        <svg class="ico" aria-hidden="true"><use href="#i-close"/></svg></button>
    <div class="glass-dlg__body" data-panel-body></div>
</dialog>
</div>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/vendor/motion/motion.js"></script>
<script src="${ctx}/js/glass-motion.js"></script>
<script src="${ctx}/js/auth-modal.js"></script>
<script src="${ctx}/js/vendor/leaflet/leaflet.js"></script>
<script src="${ctx}/js/area-map.js"></script>
<script src="${ctx}/js/my-locker.js"></script>
<script src="${ctx}/js/topup.js"></script>
<script src="${ctx}/js/glass-panel.js"></script>
<script src="${ctx}/js/locker-map.js"></script>
</body>
</html>
