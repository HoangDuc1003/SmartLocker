<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- Public page /c/{token} (CardConfirmController), the target of the link in the card e-mail. No menu, no login.
     Opening it changes nothing; only the POST of a button decides. --%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="robots" content="noindex">
    <meta name="referrer" content="no-referrer">
    <title>Confirm opening · Smart Locker</title>
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

        <div class="kiosk__card">
            <c:choose>
                <c:when test="${outcome == 'NOT_FOUND'}">
                    <h1>Invalid link</h1>
                    <p class="sub">No opening request matches this link.</p>
                    <p>Scan your card at the locker box again and open the link in the latest e-mail.</p>
                </c:when>
                <c:otherwise>
                    <h1><c:out value="${outcome == 'ASK' ? 'Confirm opening' : 'Open with your card'}"/></h1>
                    <p class="sub">Slot <c:out value="${cmd.slot_code}"/> · bank <c:out value="${cmd.bank_code}"/> · <c:out value="${cmd.area_name}"/><c:if test="${not empty cmd.location}"> · <c:out value="${cmd.location}"/></c:if></p>
                    <c:choose>
                        <c:when test="${outcome == 'ASK' or outcome == 'DEVICE_OFFLINE'}">
                            <c:if test="${outcome == 'DEVICE_OFFLINE'}">
                                <p class="kiosk__result is-wait" role="status">The box is offline, so it cannot open yet. Try again in a few seconds.</p>
                            </c:if>
                            <p>Your card was just scanned at box <code><c:out value="${cmd.device_code}"/></code> to <c:out value="${action}"/>.</p>
                            <form method="post">
                                <button type="submit" class="kiosk__submit" name="decision" value="approve">Confirm opening</button>
                                <button type="submit" class="kiosk__submit ghost" name="decision" value="reject">It was not me</button>
                            </form>
                            <p class="kiosk__help">The link works once and expires 5 minutes after the card scan.</p>
                        </c:when>
                        <c:when test="${outcome == 'OK'}">
                            <p class="kiosk__result is-ok" role="status">Confirmed. The box opens in a few seconds; stand in front of slot <c:out value="${cmd.slot_code}"/>.</p>
                        </c:when>
                        <c:when test="${outcome == 'REJECTED'}">
                            <p class="kiosk__result is-bad" role="status">Cancelled; the locker stays closed. If you did not scan your card, someone else may have it: ask the staff to block the card.</p>
                        </c:when>
                        <c:when test="${outcome == 'DONE_BEFORE'}">
                            <p class="kiosk__result is-ok" role="status">This request was already confirmed. Nothing else to do.</p>
                        </c:when>
                        <c:otherwise>
                            <p class="kiosk__result is-bad" role="status">This link has expired. Scan your card at the locker box again to get a new e-mail.</p>
                        </c:otherwise>
                    </c:choose>
                </c:otherwise>
            </c:choose>
        </div>
    </div>
</main>
</body>
</html>
