<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- Public phone page /k/{device_code} (KioskController), the target of the QR on the box and (v7) of its NFC tag.
     No menu. The PIN needs no login; "Open my locker" needs the signed-in owner and the tag token (?n=).
     js/kiosk.js posts either to /api/kiosk/unlock and shows the answer. --%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="robots" content="noindex">
    <title><c:out value="${empty device ? 'Locker box not found' : 'Open locker '.concat(device.device_code)}"/> · Smart Locker</title>
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
            <button type="button" class="icon-btn theme-toggle" aria-label="Toggle light/dark theme">
                <svg class="ico ico-moon" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
                <svg class="ico ico-sun" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
            </button>
        </div>

        <c:choose>
            <c:when test="${empty device}">
                <div class="kiosk__card">
                    <h1>Locker box not found</h1>
                    <p class="sub">There is no locker box with the code <code><c:out value="${empty deviceCode ? '–' : deviceCode}"/></code>.</p>
                    <p>Scan the QR code on the locker box again. If it still fails, tell the staff at the front desk.</p>
                </div>
            </c:when>
            <c:otherwise>
                <div class="kiosk__card">
                    <h1>Open locker <c:out value="${device.device_code}"/></h1>
                    <p class="sub">
                        <c:out value="${device.area_name}"/><c:if test="${not empty device.bank_code}"> · bank <c:out value="${device.bank_code}"/></c:if><c:if test="${not empty device.location}"> · <c:out value="${device.location}"/></c:if>
                    </p>
                    <%-- v7: the phone tap. The NFC tag of the box links here with ?n={token}; the signed-in owner of an open
                         booking on this box opens it with one button. A demo box has no reader and needs no token. --%>
                    <section class="kiosk__tap" id="kioskTap" aria-labelledby="tapTitle">
                        <c:choose>
                            <c:when test="${not empty mine and (not empty tap or device.demo)}">
                                <h2 id="tapTitle">Your locker: slot <c:out value="${mine.slot_code}"/></h2>
                                <p class="hint">Bank <c:out value="${mine.bank_code}"/> ·
                                    <c:out value="${mine.status == 'RESERVED' ? 'nothing stored yet' : 'in use'}"/>
                                    <c:if test="${device.demo}"> · demo box, no NFC tap needed</c:if></p>
                                <button type="button" class="kiosk__submit" id="tapOpen" data-tap="<c:out value='${tap}'/>"<c:if test="${device.demo}"> data-demo</c:if>>Open my locker</button>
                            </c:when>
                            <c:when test="${not empty mine}">
                                <h2 id="tapTitle">Your locker: slot <c:out value="${mine.slot_code}"/></h2>
                                <p class="hint">Hold the back of your phone to the NFC reader on the box. This page then opens again with an Open button.</p>
                            </c:when>
                            <c:when test="${not empty signedIn}">
                                <h2 id="tapTitle">Open with your phone</h2>
                                <p class="hint">Account <c:out value="${signedIn.username}"/> has no open booking at this box.
                                    For a booking with a PIN, enter the PIN below.</p>
                            </c:when>
                            <c:otherwise>
                                <h2 id="tapTitle">Open with your phone</h2>
                                <p class="hint">Sign in to open your locker with your phone, no PIN needed.</p>
                                <a class="btn kiosk__submit" href="<c:out value='${signInUrl}'/>">Sign in</a>
                            </c:otherwise>
                        </c:choose>
                    </section>
                    <form id="kioskForm" data-api="${ctx}/api/kiosk/unlock" data-device="<c:out value='${device.device_code}'/>" novalidate>
                        <label for="pin">6-digit PIN</label>
                        <input id="pin" name="pin" class="kiosk__pin" type="text" inputmode="numeric" pattern="[0-9]{6}"
                               maxlength="6" autocomplete="one-time-code" required aria-describedby="pinHelp kioskResult">
                        <p class="hint" id="pinHelp">Find your PIN under My locker on the Smart Locker website.</p>
                        <button type="submit" class="kiosk__submit" id="kioskSubmit">Open</button>
                    </form>
                    <%-- v6: a rented slot (CHOOSE) asks what to do; kiosk.js posts the same PIN (or tap) again with the intent --%>
                    <div class="kiosk__choice" id="kioskChoice" hidden>
                        <button type="button" class="kiosk__submit" data-intent="OPEN">Open</button>
                        <p class="hint">Take or add items; the booking continues.</p>
                        <button type="button" class="kiosk__submit ghost" data-intent="CHECKOUT">Check out</button>
                        <p class="hint">Take everything out; the booking ends and the slot is released.</p>
                        <button type="button" class="link" id="kioskChoiceCancel">Cancel</button>
                    </div>
                    <p class="kiosk__result" id="kioskResult" role="status" aria-live="polite" hidden></p>
                </div>
                <p class="kiosk__help">The first opening is for storing your things. During the booking, each time you open the locker, choose Open
                    (take or add items) or Check out (end the booking). The latch closes by itself after a few seconds.
                    Each NFC tap opens only once. After 5 wrong PINs, the PIN box is locked for 2 minutes.</p>
            </c:otherwise>
        </c:choose>
    </div>
</main>
<c:if test="${not empty device}"><script src="${ctx}/js/kiosk.js"></script></c:if>
</body>
</html>
