<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<%-- "now" as the UTC wall clock, the same frame as the timestamps read from the DB (it stores SYSUTCDATETIME) --%>
<% long nowMs = System.currentTimeMillis();
   pageContext.setAttribute("now", new java.util.Date(nowMs - java.util.TimeZone.getDefault().getOffset(nowMs))); %>
<c:set var="activeNav" value="mylocker"/>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<%-- ?panel=1: only the content, drawn by js/glass-panel.js as a glass popup over the users' map --%>
<c:set var="panel" value="${param.panel == '1'}"/>
<c:if test="${not panel}">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>My locker · Smart Locker</title>
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
    <div class="page-head">
        <div>
            <h2 id="pageTitle">My locker</h2>
            <p class="sub">Open bookings, how to open your locker, cards, fingerprints and booking history.</p>
        </div>
        <div class="ml-actions">
            <span class="ml-wallet ${balance lt 0 ? 'is-debt' : ''}">Wallet balance
                <b class="money"><fmt:formatNumber value="${balance}" groupingUsed="true"/> VND</b></span>
            <a class="btn ghost" href="${ctx}/LockerMapController">Book a new slot</a>
            <a class="btn ghost" href="${ctx}/TopupController">Top up</a>
        </div>
    </div>

    <%-- 1. open bookings --%>
    <section class="ml-section stack" id="booking" aria-labelledby="hBooking">
        <h3 id="hBooking" class="visually-hidden">Open bookings</h3>
        <c:forEach var="d" items="${open}">
            <c:choose>
                <c:when test="${d.openMethod == 'CARD'}"><c:set var="methodLabel" value="RFID card"/></c:when>
                <c:when test="${d.openMethod == 'PHONE'}"><c:set var="methodLabel" value="Phone"/></c:when>
                <c:when test="${d.openMethod == 'FINGERPRINT'}"><c:set var="methodLabel" value="Fingerprint"/></c:when>
                <c:otherwise><c:set var="methodLabel" value="PIN"/></c:otherwise>
            </c:choose>
            <c:set var="isOverdue" value="${d.status == 'ACTIVE' and not empty d.dueAt and d.dueAt.time lt now.time}"/>
            <c:set var="enrollExpired" value="${not empty d.enrollExpires and d.enrollExpires.time lt now.time}"/>
            <%-- v3: size of the slot, one-hour price (extension) and late fee; the fee fixed at booking time wins --%>
            <c:set var="sz" value="${sizes[d.sizeCode]}"/>
            <c:set var="lateRate" value="${not empty d.overdueRate ? d.overdueRate : (not empty sz ? sz.overdueRate : 0)}"/>
            <%-- v3 D4: cancel while the slot is held; 100% back in the first cancelMin minutes, then cancelLatePct% (rounded down to 100 VND) --%>
            <c:set var="canCancel" value="${d.status == 'RESERVED' and not empty d.holdUntil and d.holdUntil.time gt now.time}"/>
            <c:set var="freeCancel" value="${canCancel and not empty d.reservedAt and d.reservedAt.time + cancelMin * 60000 gt now.time}"/>
            <fmt:formatNumber var="lateRefund" value="${(d.paidAmount * cancelLatePct - (d.paidAmount * cancelLatePct) % 10000) / 100}" maxFractionDigits="0" groupingUsed="false"/>
            <article class="panel ml-booking" aria-labelledby="bk${d.depositId}">
                <div class="ml-booking__head">
                    <h3 id="bk${d.depositId}">Slot <c:out value="${d.slotCode}"/> <span class="muted"><c:out value="${d.bankCode}"/></span></h3>
                    <span>
                        <ui:status value="${d.status}" kind="deposit"/>
                        <c:if test="${isOverdue}"><ui:status value="OVERDUE"/></c:if>
                        <c:if test="${d.locked}"><span class="tag bad">Locked</span></c:if>
                    </span>
                </div>

                <%-- v3 D5: overdue lock, late fee, debt and the way out --%>
                <c:if test="${d.locked}">
                    <div class="ml-overdue" role="status">
                        <p class="ml-overdue__title">
                            <svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/></svg>
                            Overdue: the slot is locked</p>
                        <dl class="kv">
                            <dt>Locked at</dt><dd><ui:dt value="${d.lockedAt}"/></dd>
                            <dt>Late hours charged</dt><dd class="num">${d.overdueHours} h</dd>
                            <dt>Late fee charged</dt><dd><span class="money"><fmt:formatNumber value="${d.overdueFee}" groupingUsed="true"/> VND</span></dd>
                            <dt>Late fee per hour</dt><dd><span class="money"><fmt:formatNumber value="${lateRate}" groupingUsed="true"/> VND</span></dd>
                            <dt>Amount owed</dt><dd><span class="money ${balance lt 0 ? 'text-danger' : ''}"><fmt:formatNumber value="${balance lt 0 ? -balance : 0}" groupingUsed="true"/> VND</span></dd>
                        </dl>
                        <p class="hint">
                            <c:choose>
                                <c:when test="${balance lt 0}">Top up until your balance is 0 VND or more, then open the locker to pick up your things. Each extra late hour is still charged.</c:when>
                                <c:otherwise>Your balance is enough: open the locker to pick up your things now. Each extra late hour is still charged.</c:otherwise>
                            </c:choose>
                            A locked slot cannot be extended.</p>
                        <c:if test="${not empty d.escalatedAt}">
                            <p class="ml-overdue__escalated">The booking has been overdue for more than ${escalateHours} h, so it was handed to the staff
                                (at <ui:dt value="${d.escalatedAt}"/>). Contact the front desk to get your things back.</p>
                        </c:if>
                        <div><a class="btn ${balance lt 0 ? '' : 'ghost'}" href="${ctx}/TopupController">Top up</a></div>
                    </div>
                </c:if>
                <c:if test="${isOverdue and not d.locked}">
                    <p class="notice">The due time has passed. The locker locks after the ${d.graceMin}-min grace period; then each late hour
                        costs <fmt:formatNumber value="${lateRate}" groupingUsed="true"/> VND, counted from the due time.</p>
                </c:if>

                <c:if test="${d.status == 'RESERVED' and not empty d.holdUntil}">
                    <div>
                        <div class="muted">Starts by itself at <ui:dt value="${d.holdUntil}"/></div>
                        <div class="countdown-big" data-countdown="<c:out value='${d.holdUntil}'/>" data-late-text="The booking has started, reload the page" aria-live="off">&nbsp;</div>
                        <p class="hint">The slot is held for ${holdMin} min after booking. When the hold ends, the booking starts by itself and can no longer be cancelled: the slot stays locked for you, and whether you come early, late or not at all, you can use it for the time you paid. No refund.</p>
                    </div>
                </c:if>

                <dl class="kv">
                    <dt>Locker box</dt><dd><code><c:out value="${empty d.deviceCode ? '–' : d.deviceCode}"/></code></dd>
                    <dt>Slot size</dt><dd><c:out value="${d.sizeCode}"/>
                        <c:if test="${not empty d.sizeCm}"><span class="muted"><c:out value="${d.sizeCm}"/> cm</span></c:if></dd>
                    <c:if test="${lateRate gt 0}">
                        <dt>Late fee</dt><dd><span class="money"><fmt:formatNumber value="${lateRate}" groupingUsed="true"/> VND</span> <span class="muted">per hour</span></dd>
                    </c:if>
                    <dt>Storage plan</dt><dd><c:out value="${d.planName}"/></dd>
                    <dt>Paid</dt><dd><span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND</span></dd>
                    <dt>Open method</dt><dd><c:out value="${methodLabel}"/></dd>
                    <dt>Booked</dt><dd><ui:dt value="${d.reservedAt}"/></dd>
                    <c:if test="${d.status == 'ACTIVE'}">
                        <dt>Started</dt><dd><ui:dt value="${d.startedAt}"/></dd>
                        <dt>Due</dt><dd><ui:dt value="${d.dueAt}"/>
                            <c:if test="${not empty d.dueAt}"> · <span data-countdown="<c:out value='${d.dueAt}'/>" data-late-text="Past the due time">&nbsp;</span></c:if></dd>
                        <dt>Openings</dt><dd class="num">${d.accessCount} <c:choose><c:when test="${d.accessCount == 1}">time</c:when><c:otherwise>times</c:otherwise></c:choose> <span class="muted">(besides storing your things)</span></dd>
                    </c:if>
                </dl>

                <c:choose>
                    <%-- PIN: masked until the owner asks --%>
                    <c:when test="${d.openMethod == 'PIN' and not empty d.pinCode}">
                        <div class="ml-code">
                            <span class="ml-code__label" id="pinLabel${d.depositId}">Locker PIN</span>
                            <span class="ml-code__value" data-pin-mask aria-labelledby="pinLabel${d.depositId}">••••••</span>
                            <span class="ml-code__value" data-pin-value hidden><c:out value="${d.pinCode}"/></span>
                            <button type="button" class="ghost btn--sm" data-pin-toggle aria-pressed="false">Show PIN</button>
                            <p class="hint">Type the 6 digits on the keypad of the box, or scan the QR code on the box and type them on your phone.
                                <c:if test="${not empty d.deviceCode}"><a href="${ctx}/k/<c:out value='${d.deviceCode}'/>">Open the PIN page</a>.</c:if>
                                <c:out value="${d.status == 'RESERVED' ? 'The first PIN opens the locker to store your things; the next one opens it to pick them up and end the booking.' : 'Enter the PIN again to pick up your things and end the booking.'}"/></p>
                        </div>
                    </c:when>
                    <%-- card or fingerprint not enrolled yet at this box: the 6-digit enroll code --%>
                    <c:when test="${not empty d.enrollCode}">
                        <div class="ml-code">
                            <span class="ml-code__label"><c:out value="${d.openMethod == 'CARD' ? 'Card' : 'Fingerprint'}"/> enrollment code</span>
                            <c:choose>
                                <c:when test="${enrollExpired}">
                                    <span class="ml-code__value muted"><s><c:out value="${d.enrollCode}"/></s></span>
                                    <form method="post" action="${ctx}/MyLockerController">
                                        <input type="hidden" name="action" value="newEnrollCode">
                                        <input type="hidden" name="depositId" value="${d.depositId}">
                                        <button type="submit" class="btn--sm">Get a new code</button>
                                    </form>
                                    <p class="hint">The code expired at <ui:dt value="${d.enrollExpires}"/>.</p>
                                </c:when>
                                <c:otherwise>
                                    <span class="ml-code__value"><c:out value="${d.enrollCode}"/></span>
                                    <p class="hint">Valid until <ui:dt value="${d.enrollExpires}"/>
                                        (<span data-countdown="<c:out value='${d.enrollExpires}'/>" data-late-text="expired, reload the page to get a new code">&nbsp;</span>).</p>
                                </c:otherwise>
                            </c:choose>
                            <ol class="ml-steps">
                                <li>Go to the box <code><c:out value="${empty d.deviceCode ? 'of the locker bank' : d.deviceCode}"/></code>.</li>
                                <li>Press <b><c:out value="${d.openMethod == 'CARD' ? 'B' : 'C'}"/></b> on the box, then type the enrollment code.</li>
                                <c:choose>
                                    <c:when test="${d.openMethod == 'CARD'}">
                                        <li>Tap your card on the reader.</li>
                                        <li>Tap the card again to open the locker.</li>
                                    </c:when>
                                    <c:otherwise>
                                        <li>Place the same finger on the sensor 2 times.</li>
                                        <li>Place that finger once more to open the locker.</li>
                                    </c:otherwise>
                                </c:choose>
                            </ol>
                        </div>
                    </c:when>
                    <c:when test="${d.openMethod == 'CARD'}">
                        <p class="hint">Tap your enrolled card at box <code><c:out value="${d.deviceCode}"/></code> to
                            <c:out value="${d.status == 'RESERVED' ? 'open the locker and store your things' : 'pick up your things and end the booking'}"/>.</p>
                    </c:when>
                    <%-- v7: the phone tap. The NFC tag of the box opens /k/{device} with a fresh token; a demo box needs none --%>
                    <c:when test="${d.openMethod == 'PHONE'}">
                        <p class="hint">Sign in on your phone, hold the back of the phone to the NFC reader of box
                            <code><c:out value="${d.deviceCode}"/></code>, then press Open my locker to
                            <c:out value="${d.status == 'RESERVED' ? 'open the locker and store your things' : 'open the locker or check out'}"/>.
                            <c:if test="${not empty d.deviceCode}"><a href="${ctx}/k/<c:out value='${d.deviceCode}'/>">Open the page of the box</a>
                                (a demo box has no NFC reader and opens right on that page).</c:if></p>
                    </c:when>
                    <c:when test="${d.openMethod == 'FINGERPRINT'}">
                        <p class="hint">Place your enrolled finger on the sensor of box <code><c:out value="${d.deviceCode}"/></code> to
                            <c:out value="${d.status == 'RESERVED' ? 'open the locker and store your things' : 'pick up your things and end the booking'}"/>.</p>
                    </c:when>
                </c:choose>

                <div class="ml-actions">
                    <c:choose>
                        <c:when test="${canCancel}">
                            <%-- user-pages.js switches to the partial refund when the free minutes end and removes the form when the hold ends;
                                 expectedRefund is what the popup showed, the procedure refuses a lower refund --%>
                            <c:set var="fullText">Cancel the booking of slot <c:out value='${d.slotCode}'/>? The full <fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND goes back to your wallet.</c:set>
                            <c:set var="lateText">Cancel the booking of slot <c:out value='${d.slotCode}'/>? More than ${cancelMin} min have passed since booking, so only ${cancelLatePct}% is refunded: <fmt:formatNumber value="${lateRefund}" groupingUsed="true"/> VND goes back to your wallet.</c:set>
                            <c:set var="lateLabel">${cancelLatePct}% refund (<fmt:formatNumber value="${lateRefund}" groupingUsed="true"/> VND) if cancelled within</c:set>
                            <form method="post" action="${ctx}/BookingController" data-cancel-from="<c:out value='${d.reservedAt}'/>" data-cancel-min="${cancelMin}"
                                  data-hold-until="<c:out value='${d.holdUntil}'/>" data-late-refund="${lateRefund}"
                                  data-confirm-late="${lateText}" data-late-label="${lateLabel}" ${freeCancel ? '' : 'data-late'}
                                  data-confirm="${freeCancel ? fullText : lateText}" data-confirm-ok="Cancel booking" data-confirm-danger>
                                <input type="hidden" name="action" value="cancel">
                                <input type="hidden" name="depositId" value="${d.depositId}">
                                <input type="hidden" name="back" value="list">
                                <input type="hidden" name="expectedRefund" value="${freeCancel ? d.paidAmount : lateRefund}" data-expected-refund>
                                <button type="submit" class="ghost">Cancel booking</button>
                                <span class="muted"><span data-cancel-label>${freeCancel ? 'Full refund if cancelled within' : lateLabel}</span>: <b class="num" data-cancel-left>&nbsp;</b></span>
                            </form>
                        </c:when>
                        <c:when test="${d.status == 'RESERVED'}">
                            <span class="muted">The hold time is over, so the booking can no longer be cancelled.</span>
                        </c:when>
                        <c:when test="${d.locked}">
                            <span class="muted">An overdue, locked slot cannot be extended.</span>
                        </c:when>
                        <c:when test="${d.extendCount < 3 and not empty sz}">
                            <%-- v3 D10: CEILING(minutes / 60) x the hour price of the size, taken at once; user-pages.js keeps
                                 data-confirm in step with the chosen option --%>
                            <form method="post" action="${ctx}/BookingController" data-extend-form
                                  data-confirm="Extend by 1 hour? <fmt:formatNumber value="${sz.hourRate}" groupingUsed="true"/> VND is taken from your wallet now." data-confirm-ok="Extend">
                                <input type="hidden" name="action" value="extend">
                                <input type="hidden" name="depositId" value="${d.depositId}">
                                <input type="hidden" name="back" value="list">
                                <select name="minutes" aria-label="Extension time">
                                    <option value="30" data-price="${sz.hourRate}">+30 min · <fmt:formatNumber value="${sz.hourRate}" groupingUsed="true"/> VND</option>
                                    <option value="60" data-price="${sz.hourRate}" selected>+1 hour · <fmt:formatNumber value="${sz.hourRate}" groupingUsed="true"/> VND</option>
                                    <option value="120" data-price="${sz.hourRate * 2}">+2 hours · <fmt:formatNumber value="${sz.hourRate * 2}" groupingUsed="true"/> VND</option>
                                    <option value="240" data-price="${sz.hourRate * 4}">+4 hours · <fmt:formatNumber value="${sz.hourRate * 4}" groupingUsed="true"/> VND</option>
                                </select>
                                <button type="submit" class="ghost">Extend (${d.extendCount}/3)</button>
                            </form>
                        </c:when>
                        <c:otherwise><span class="muted">Maximum extensions reached (3/3)</span></c:otherwise>
                    </c:choose>
                </div>
            </article>
        </c:forEach>
        <c:if test="${empty open}">
            <div class="panel"><p class="ml-empty">You have no open booking. Open the <a href="${ctx}/LockerMapController">locker map</a> to choose an available slot.</p></div>
        </c:if>
    </section>

    <%-- v3 D8: e-mail for the due reminder, saved as typed (also set at registration). --%>
    <section class="ml-section" id="reminder" aria-labelledby="hReminder">
        <h3 id="hReminder">Due reminder e-mail</h3>
        <div class="panel ml-reminder">
            <p class="hint">15 minutes before the due time, the system sends a reminder e-mail with the slot, the area and the late fee per hour.</p>
            <c:if test="${not mailEnabled}">
                <p class="notice">The server is not set up to send e-mail yet, so reminders cannot be sent for now. You can still save your address.</p>
            </c:if>
            <p class="ml-reminder__now">
                <c:choose>
                    <c:when test="${not empty email}">Reminders go to <b><c:out value="${email}"/></b>.</c:when>
                    <c:otherwise>You have not set a reminder e-mail.</c:otherwise>
                </c:choose>
            </p>
            <div class="ml-reminder__forms">
                <form method="post" action="${ctx}/MyLockerController" class="ml-inline-form">
                    <input type="hidden" name="action" value="setEmail">
                    <label for="reminderEmail"><c:out value="${empty email ? 'E-mail for reminders' : 'Change to another e-mail'}"/></label>
                    <div class="ml-inline-form__row">
                        <input type="email" id="reminderEmail" name="email" required maxlength="150" autocomplete="email"
                               value="<c:out value='${email}'/>">
                        <button type="submit">Save e-mail</button>
                    </div>
                </form>
                <c:if test="${not empty email}">
                    <form method="post" action="${ctx}/MyLockerController" data-confirm="Turn off reminder e-mails? You will no longer get a reminder before the due time." data-confirm-ok="Turn off reminders">
                        <input type="hidden" name="action" value="setEmail">
                        <input type="hidden" name="email" value="">
                        <button type="submit" class="link">Turn off reminder e-mails</button>
                    </form>
                </c:if>
            </div>
        </div>
    </section>

    <%-- 2. cards --%>
    <section class="ml-section" id="cards" aria-labelledby="hCards">
        <h3 id="hCards">Cards</h3>
        <p class="hint">Cards are enrolled for free at a box. Reporting a card lost blocks it at once; it no longer opens any locker.</p>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Card UID</th><th>Status</th><th>Enrolled at box</th><th>Actions</th></tr>
            <c:forEach var="c" items="${cards}">
            <tr class="${c.status == 'LOST' or c.status == 'BLOCKED' ? 'locked' : ''}">
                <td><code><c:out value="${c.card_uid}"/></code></td>
                <td><ui:status value="${c.status}"/></td>
                <td><c:out value="${empty c.registered_device ? '–' : c.registered_device}"/></td>
                <td class="ops">
                    <c:choose>
                        <c:when test="${c.status == 'ACTIVE'}">
                            <form method="post" action="${ctx}/MyCardController" data-confirm="Report card <c:out value='${c.card_uid}'/> lost? It is blocked at once and no longer opens any locker." data-confirm-ok="Report lost" data-confirm-danger>
                                <input type="hidden" name="action" value="reportLost">
                                <input type="hidden" name="cardId" value="${c.card_id}">
                                <button type="submit" class="link danger">Report lost</button>
                            </form>
                        </c:when>
                        <c:otherwise><span class="muted">–</span></c:otherwise>
                    </c:choose>
                </td>
            </tr>
            </c:forEach>
            <c:if test="${empty cards}"><tr><td colspan="4" class="empty">You have no card yet. When you book, choose RFID card and enroll it at the box with the enrollment code.</td></tr></c:if>
        </table>
        </div>
    </section>

    <%-- 3. fingerprints, one per box --%>
    <section class="ml-section" id="fingerprints" aria-labelledby="hFp">
        <h3 id="hFp">Fingerprints</h3>
        <p class="hint">A fingerprint is enrolled once per box and reused for later bookings.</p>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Locker box</th><th>Template slot</th><th>Enrolled</th><th>Actions</th></tr>
            <c:forEach var="f" items="${fingerprints}">
            <tr>
                <td><code><c:out value="${f.device_code}"/></code></td>
                <td class="num"><c:out value="${f.sensor_slot}"/></td>
                <td><ui:dt value="${f.created_at}"/></td>
                <td class="ops">
                    <form method="post" action="${ctx}/MyLockerController" data-confirm="Delete the fingerprint on box <c:out value='${f.device_code}'/>? Next time you choose Fingerprint you must enroll again." data-confirm-ok="Delete fingerprint" data-confirm-danger>
                        <input type="hidden" name="action" value="deleteFingerprint">
                        <input type="hidden" name="fpId" value="${f.fp_id}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </td>
            </tr>
            </c:forEach>
            <c:if test="${empty fingerprints}"><tr><td colspan="4" class="empty">You have not enrolled a fingerprint on any box.</td></tr></c:if>
        </table>
        </div>
    </section>

    <%-- 4. history --%>
    <section class="ml-section" id="history" aria-labelledby="hHistory">
        <h3 id="hHistory">Booking history</h3>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Slot</th><th>Locker bank</th><th>Plan</th><th>Open method</th><th>Payment</th><th>Status</th><th>Booked</th><th>Ended</th></tr>
            <c:forEach var="d" items="${history}">
            <tr>
                <td><b><c:out value="${d.slotCode}"/></b></td>
                <td><c:out value="${d.bankCode}"/></td>
                <td><c:out value="${d.planName}"/></td>
                <td><c:out value="${d.openMethod == 'CARD' ? 'RFID card' : d.openMethod == 'PHONE' ? 'Phone' : d.openMethod == 'FINGERPRINT' ? 'Fingerprint' : 'PIN'}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${d.paidAmount == 0}"><span class="tag">Free</span></c:when>
                        <c:when test="${d.status == 'NO_SHOW'}">
                            <span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND</span>
                            <c:set var="refund" value="${refunds[d.depositId]}"/>
                            <c:choose>
                                <c:when test="${empty refund}"></c:when>
                                <c:when test="${refund == 0}"><span class="muted">no-show, no refund</span></c:when>
                                <c:otherwise><span class="muted">refunded <fmt:formatNumber value="${refund}" groupingUsed="true"/> VND</span></c:otherwise>
                            </c:choose>
                        </c:when>
                        <c:when test="${d.status == 'CANCELLED'}">
                            <span class="muted">Refunded <span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND</span></span>
                        </c:when>
                        <c:otherwise><span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> VND</span></c:otherwise>
                    </c:choose>
                </td>
                <td><ui:status value="${d.status}" kind="deposit"/></td>
                <td><ui:dt value="${d.reservedAt}"/></td>
                <td><ui:dt value="${d.endedAt}"/></td>
            </tr>
            </c:forEach>
            <c:if test="${empty history}"><tr><td colspan="8" class="empty">No finished bookings yet.</td></tr></c:if>
        </table>
        </div>
    </section>
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
