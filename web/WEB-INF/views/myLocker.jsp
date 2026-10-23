<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<%-- "now" as the UTC wall clock, the same frame as the timestamps read from the DB (it stores SYSUTCDATETIME) --%>
<% long nowMs = System.currentTimeMillis();
   pageContext.setAttribute("now", new java.util.Date(nowMs - java.util.TimeZone.getDefault().getOffset(nowMs))); %>
<c:set var="activeNav" value="mylocker"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Tủ của tôi · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <div>
            <h2>Tủ của tôi</h2>
            <p class="sub">Lượt đặt đang mở, cách mở tủ, thẻ từ, vân tay và lịch sử gửi đồ.</p>
        </div>
        <div class="ml-actions">
            <span class="ml-wallet ${balance lt 0 ? 'is-debt' : ''}">Số dư ví
                <b class="money"><fmt:formatNumber value="${balance}" groupingUsed="true"/> đ</b></span>
            <a class="btn ghost" href="${ctx}/LockerMapController">Đặt ngăn mới</a>
            <a class="btn ghost" href="${ctx}/TopupController">Nạp tiền</a>
        </div>
    </div>

    <%-- 1. open bookings --%>
    <section class="ml-section stack" id="booking" aria-labelledby="hBooking">
        <h3 id="hBooking" class="visually-hidden">Lượt đang mở</h3>
        <c:forEach var="d" items="${open}">
            <c:choose>
                <c:when test="${d.openMethod == 'CARD'}"><c:set var="methodLabel" value="Thẻ từ"/></c:when>
                <c:when test="${d.openMethod == 'FINGERPRINT'}"><c:set var="methodLabel" value="Vân tay"/></c:when>
                <c:otherwise><c:set var="methodLabel" value="Mật mã"/></c:otherwise>
            </c:choose>
            <c:set var="isOverdue" value="${d.status == 'ACTIVE' and not empty d.dueAt and d.dueAt.time lt now.time}"/>
            <c:set var="enrollExpired" value="${not empty d.enrollExpires and d.enrollExpires.time lt now.time}"/>
            <%-- v3: size of the slot, one-hour price (extension) and late fee; the fee fixed at booking time wins --%>
            <c:set var="sz" value="${sizes[d.sizeCode]}"/>
            <c:set var="lateRate" value="${not empty d.overdueRate ? d.overdueRate : (not empty sz ? sz.overdueRate : 0)}"/>
            <c:set var="canCancel" value="${d.status == 'RESERVED' and not empty d.reservedAt and d.reservedAt.time + cancelMin * 60000 gt now.time}"/>
            <article class="panel ml-booking" aria-labelledby="bk${d.depositId}">
                <div class="ml-booking__head">
                    <h3 id="bk${d.depositId}">Ngăn <c:out value="${d.slotCode}"/> <span class="muted"><c:out value="${d.bankCode}"/></span></h3>
                    <span>
                        <ui:status value="${d.status}" kind="deposit"/>
                        <c:if test="${isOverdue}"><ui:status value="OVERDUE"/></c:if>
                        <c:if test="${d.locked}"><span class="tag bad">Đang khóa</span></c:if>
                    </span>
                </div>

                <%-- v3 D5: overdue lock, late fee, debt and the way out --%>
                <c:if test="${d.locked}">
                    <div class="ml-overdue" role="status">
                        <p class="ml-overdue__title">
                            <svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/></svg>
                            Đã quá hạn, tủ đang khóa</p>
                        <dl class="kv">
                            <dt>Khóa lúc</dt><dd><ui:dt value="${d.lockedAt}"/></dd>
                            <dt>Giờ trễ đã tính</dt><dd class="num">${d.overdueHours} giờ</dd>
                            <dt>Phụ phí đã thu</dt><dd><span class="money"><fmt:formatNumber value="${d.overdueFee}" groupingUsed="true"/> đ</span></dd>
                            <dt>Phụ phí mỗi giờ</dt><dd><span class="money"><fmt:formatNumber value="${lateRate}" groupingUsed="true"/> đ</span></dd>
                            <dt>Số tiền đang nợ</dt><dd><span class="money ${balance lt 0 ? 'text-danger' : ''}"><fmt:formatNumber value="${balance lt 0 ? -balance : 0}" groupingUsed="true"/> đ</span></dd>
                        </dl>
                        <p class="hint">
                            <c:choose>
                                <c:when test="${balance lt 0}">Hãy nạp tiền để số dư từ 0 đ trở lên, rồi mở tủ để lấy đồ. Mỗi giờ trễ thêm vẫn bị tính phụ phí.</c:when>
                                <c:otherwise>Số dư đã đủ: mở tủ để lấy đồ ngay. Mỗi giờ trễ thêm vẫn bị tính phụ phí.</c:otherwise>
                            </c:choose>
                            Không gia hạn được khi tủ đã khóa.</p>
                        <c:if test="${not empty d.escalatedAt}">
                            <p class="ml-overdue__escalated">Lượt gửi đã quá hạn hơn ${escalateHours} giờ nên đã được chuyển cho nhân viên xử lý
                                (lúc <ui:dt value="${d.escalatedAt}"/>). Hãy liên hệ quầy để nhận lại đồ.</p>
                        </c:if>
                        <div><a class="btn ${balance lt 0 ? '' : 'ghost'}" href="${ctx}/TopupController">Nạp tiền</a></div>
                    </div>
                </c:if>
                <c:if test="${isOverdue and not d.locked}">
                    <p class="notice">Đã quá hạn trả. Tủ sẽ khóa sau thời gian ân hạn ${d.graceMin} phút; khi đó mỗi giờ trễ
                        tính phụ phí <fmt:formatNumber value="${lateRate}" groupingUsed="true"/> đ, kể từ hạn trả.</p>
                </c:if>

                <c:if test="${d.status == 'RESERVED' and not empty d.holdUntil}">
                    <div>
                        <div class="muted">Giữ chỗ đến <ui:dt value="${d.holdUntil}"/></div>
                        <div class="countdown-big" data-countdown="<c:out value='${d.holdUntil}'/>" data-late-text="Đã hết thời gian giữ chỗ" aria-live="off">&nbsp;</div>
                        <p class="hint">Giữ chỗ ${holdMin} phút từ lúc đặt. Không đến trong thời gian này sẽ mất toàn bộ số tiền đã trả.</p>
                    </div>
                </c:if>

                <dl class="kv">
                    <dt>Hộp tủ</dt><dd><code><c:out value="${empty d.deviceCode ? '–' : d.deviceCode}"/></code></dd>
                    <dt>Cỡ ngăn</dt><dd><c:out value="${d.sizeCode}"/>
                        <c:if test="${not empty d.sizeCm}"><span class="muted"><c:out value="${d.sizeCm}"/> cm</span></c:if></dd>
                    <c:if test="${lateRate gt 0}">
                        <dt>Phụ phí trễ hạn</dt><dd><span class="money"><fmt:formatNumber value="${lateRate}" groupingUsed="true"/> đ</span> <span class="muted">mỗi giờ</span></dd>
                    </c:if>
                    <dt>Gói gửi</dt><dd><c:out value="${d.planName}"/></dd>
                    <dt>Đã trả</dt><dd><span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> đ</span></dd>
                    <dt>Cách mở</dt><dd><c:out value="${methodLabel}"/></dd>
                    <dt>Đặt lúc</dt><dd><ui:dt value="${d.reservedAt}"/></dd>
                    <c:if test="${d.status == 'ACTIVE'}">
                        <dt>Bắt đầu gửi</dt><dd><ui:dt value="${d.startedAt}"/></dd>
                        <dt>Hạn trả</dt><dd><ui:dt value="${d.dueAt}"/>
                            <c:if test="${not empty d.dueAt}"> · <span data-countdown="<c:out value='${d.dueAt}'/>" data-late-text="Đã quá hạn trả">&nbsp;</span></c:if></dd>
                    </c:if>
                </dl>

                <c:choose>
                    <%-- PIN: masked until the owner asks --%>
                    <c:when test="${d.openMethod == 'PIN' and not empty d.pinCode}">
                        <div class="ml-code">
                            <span class="ml-code__label" id="pinLabel${d.depositId}">Mật mã mở tủ</span>
                            <span class="ml-code__value" data-pin-mask aria-labelledby="pinLabel${d.depositId}">••••••</span>
                            <span class="ml-code__value" data-pin-value hidden><c:out value="${d.pinCode}"/></span>
                            <button type="button" class="ghost btn--sm" data-pin-toggle aria-pressed="false">Hiện mật mã</button>
                            <p class="hint">Nhập 6 số trên bàn phím của hộp, hoặc quét mã QR dán trên hộp rồi nhập trên điện thoại.
                                <c:if test="${not empty d.deviceCode}"><a href="${ctx}/k/<c:out value='${d.deviceCode}'/>">Mở trang nhập mã</a>.</c:if>
                                <c:out value="${d.status == 'RESERVED' ? 'Lần nhập đầu mở tủ để cất đồ, lần sau mở tủ để lấy đồ và kết thúc lượt.' : 'Nhập lại mật mã để lấy đồ và kết thúc lượt.'}"/></p>
                        </div>
                    </c:when>
                    <%-- card or fingerprint not enrolled yet at this box: the 6-digit enroll code --%>
                    <c:when test="${not empty d.enrollCode}">
                        <div class="ml-code">
                            <span class="ml-code__label">Mã đăng ký <c:out value="${d.openMethod == 'CARD' ? 'thẻ từ' : 'vân tay'}"/></span>
                            <c:choose>
                                <c:when test="${enrollExpired}">
                                    <span class="ml-code__value muted"><s><c:out value="${d.enrollCode}"/></s></span>
                                    <form method="post" action="${ctx}/MyLockerController">
                                        <input type="hidden" name="action" value="newEnrollCode">
                                        <input type="hidden" name="depositId" value="${d.depositId}">
                                        <button type="submit" class="btn--sm">Lấy mã mới</button>
                                    </form>
                                    <p class="hint">Mã đã hết hạn lúc <ui:dt value="${d.enrollExpires}"/>.</p>
                                </c:when>
                                <c:otherwise>
                                    <span class="ml-code__value"><c:out value="${d.enrollCode}"/></span>
                                    <p class="hint">Có hạn đến <ui:dt value="${d.enrollExpires}"/>
                                        (<span data-countdown="<c:out value='${d.enrollExpires}'/>" data-late-text="đã hết hạn, tải lại trang để lấy mã mới">&nbsp;</span>).</p>
                                </c:otherwise>
                            </c:choose>
                            <ol class="ml-steps">
                                <li>Tới hộp <code><c:out value="${empty d.deviceCode ? 'của dãy tủ' : d.deviceCode}"/></code>.</li>
                                <li>Bấm <b><c:out value="${d.openMethod == 'CARD' ? 'B' : 'C'}"/></b> trên hộp rồi nhập mã đăng ký.</li>
                                <c:choose>
                                    <c:when test="${d.openMethod == 'CARD'}">
                                        <li>Quẹt thẻ lên đầu đọc. <c:if test="${cardDepositDue}">Ví bị trừ cọc <fmt:formatNumber value="${cardDeposit}" groupingUsed="true"/> đ khi đăng ký xong.</c:if></li>
                                        <li>Quẹt thẻ lần nữa để mở tủ.</li>
                                    </c:when>
                                    <c:otherwise>
                                        <li>Đặt cùng một ngón tay 2 lần lên cảm biến.</li>
                                        <li>Đặt ngón tay đó lần nữa để mở tủ.</li>
                                    </c:otherwise>
                                </c:choose>
                            </ol>
                        </div>
                    </c:when>
                    <c:when test="${d.openMethod == 'CARD'}">
                        <p class="hint">Quẹt thẻ đã đăng ký tại hộp <code><c:out value="${d.deviceCode}"/></code> để
                            <c:out value="${d.status == 'RESERVED' ? 'mở tủ và cất đồ' : 'lấy đồ và kết thúc lượt'}"/>.</p>
                    </c:when>
                    <c:when test="${d.openMethod == 'FINGERPRINT'}">
                        <p class="hint">Đặt ngón tay đã đăng ký lên cảm biến của hộp <code><c:out value="${d.deviceCode}"/></code> để
                            <c:out value="${d.status == 'RESERVED' ? 'mở tủ và cất đồ' : 'lấy đồ và kết thúc lượt'}"/>.</p>
                    </c:when>
                </c:choose>

                <div class="ml-actions">
                    <c:choose>
                        <c:when test="${d.status == 'RESERVED' and canCancel}">
                            <%-- v3 D4: free cancel only in the first minutes; my-locker.js removes the form when the time is up --%>
                            <form method="post" action="${ctx}/BookingController" data-cancel-from="<c:out value='${d.reservedAt}'/>" data-cancel-min="${cancelMin}"
                                  data-confirm="Hủy lượt đặt ngăn <c:out value='${d.slotCode}'/>? Số tiền đã trả được hoàn đủ vào ví." data-confirm-ok="Hủy đặt" data-confirm-danger>
                                <input type="hidden" name="action" value="cancel">
                                <input type="hidden" name="depositId" value="${d.depositId}">
                                <input type="hidden" name="back" value="list">
                                <button type="submit" class="ghost">Hủy đặt</button>
                                <span class="muted">Còn hủy được: <b class="num" data-cancel-left>&nbsp;</b></span>
                            </form>
                        </c:when>
                        <c:when test="${d.status == 'RESERVED'}">
                            <span class="muted">Đã quá ${cancelMin} phút kể từ lúc đặt nên không hủy được nữa.</span>
                        </c:when>
                        <c:when test="${d.locked}">
                            <span class="muted">Không gia hạn được khi tủ đã khóa vì quá hạn.</span>
                        </c:when>
                        <c:when test="${d.extendCount < 3 and not empty sz}">
                            <%-- v3 D10: CEILING(minutes / 60) x the hour price of the size, taken at once; my-locker.js keeps
                                 data-confirm in step with the chosen option --%>
                            <form method="post" action="${ctx}/BookingController" data-extend-form
                                  data-confirm="Gia hạn thêm 1 giờ? Ví bị trừ ngay <fmt:formatNumber value="${sz.hourRate}" groupingUsed="true"/> đ." data-confirm-ok="Gia hạn">
                                <input type="hidden" name="action" value="extend">
                                <input type="hidden" name="depositId" value="${d.depositId}">
                                <input type="hidden" name="back" value="list">
                                <select name="minutes" aria-label="Thời gian gia hạn">
                                    <option value="30" data-price="${sz.hourRate}">+30 phút · <fmt:formatNumber value="${sz.hourRate}" groupingUsed="true"/> đ</option>
                                    <option value="60" data-price="${sz.hourRate}" selected>+1 giờ · <fmt:formatNumber value="${sz.hourRate}" groupingUsed="true"/> đ</option>
                                    <option value="120" data-price="${sz.hourRate * 2}">+2 giờ · <fmt:formatNumber value="${sz.hourRate * 2}" groupingUsed="true"/> đ</option>
                                    <option value="240" data-price="${sz.hourRate * 4}">+4 giờ · <fmt:formatNumber value="${sz.hourRate * 4}" groupingUsed="true"/> đ</option>
                                </select>
                                <button type="submit" class="ghost">Gia hạn (${d.extendCount}/3)</button>
                            </form>
                        </c:when>
                        <c:otherwise><span class="muted">Đã gia hạn tối đa (3/3)</span></c:otherwise>
                    </c:choose>
                </div>
            </article>
        </c:forEach>
        <c:if test="${empty open}">
            <div class="panel"><p class="ml-empty">Bạn chưa có lượt đặt nào đang mở. Mở <a href="${ctx}/LockerMapController">sơ đồ tủ</a> để chọn một ngăn trống.</p></div>
        </c:if>
    </section>

    <%-- v3 D8: e-mail for the due reminder, saved as typed (also set at registration). --%>
    <section class="ml-section" id="reminder" aria-labelledby="hReminder">
        <h3 id="hReminder">Email nhắc hạn</h3>
        <div class="panel ml-reminder">
            <p class="hint">Trước khi tới hạn trả 15 phút, hệ thống gửi một email nhắc kèm ngăn, khu và phụ phí mỗi giờ nếu trễ.</p>
            <c:if test="${not mailEnabled}">
                <p class="notice">Máy chủ chưa được cấu hình gửi email nên tạm thời chưa gửi được nhắc hạn. Bạn vẫn lưu được địa chỉ.</p>
            </c:if>
            <p class="ml-reminder__now">
                <c:choose>
                    <c:when test="${not empty email}">Đang nhận nhắc hạn tại <b><c:out value="${email}"/></b>.</c:when>
                    <c:otherwise>Bạn chưa đăng ký email nhắc hạn.</c:otherwise>
                </c:choose>
            </p>
            <div class="ml-reminder__forms">
                <form method="post" action="${ctx}/MyLockerController" class="ml-inline-form">
                    <input type="hidden" name="action" value="setEmail">
                    <label for="reminderEmail"><c:out value="${empty email ? 'Email nhận nhắc hạn' : 'Đổi sang email khác'}"/></label>
                    <div class="ml-inline-form__row">
                        <input type="email" id="reminderEmail" name="email" required maxlength="150" autocomplete="email"
                               value="<c:out value='${email}'/>">
                        <button type="submit">Lưu email</button>
                    </div>
                </form>
                <c:if test="${not empty email}">
                    <form method="post" action="${ctx}/MyLockerController" data-confirm="Tắt email nhắc hạn? Bạn sẽ không nhận thư nhắc trước hạn trả nữa." data-confirm-ok="Tắt nhắc hạn">
                        <input type="hidden" name="action" value="setEmail">
                        <input type="hidden" name="email" value="">
                        <button type="submit" class="link">Tắt email nhắc hạn</button>
                    </form>
                </c:if>
            </div>
        </div>
    </section>

    <%-- 2. cards --%>
    <section class="ml-section" id="cards" aria-labelledby="hCards">
        <h3 id="hCards">Thẻ từ</h3>
        <p class="hint">Cọc thẻ <fmt:formatNumber value="${cardDeposit}" groupingUsed="true"/> đ thu một lần khi đăng ký thẻ tại hộp.
            Báo mất sẽ khóa thẻ ngay và không hoàn cọc; nhân viên thu hồi thẻ thì hoàn cọc.</p>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Mã thẻ (UID)</th><th>Trạng thái</th><th>Tiền cọc</th><th>Đăng ký tại hộp</th><th>Thao tác</th></tr>
            <c:forEach var="c" items="${cards}">
            <tr class="${c.status == 'LOST' or c.status == 'BLOCKED' ? 'locked' : ''}">
                <td><code><c:out value="${c.card_uid}"/></code></td>
                <td><ui:status value="${c.status}"/></td>
                <td><span class="money"><fmt:formatNumber value="${c.deposit_amount}" groupingUsed="true"/> đ</span></td>
                <td><c:out value="${empty c.registered_device ? '–' : c.registered_device}"/></td>
                <td class="ops">
                    <c:choose>
                        <c:when test="${c.status == 'ACTIVE'}">
                            <form method="post" action="${ctx}/MyCardController" data-confirm="Báo mất thẻ <c:out value='${c.card_uid}'/>? Thẻ bị khóa ngay và không mở được tủ nữa." data-confirm-ok="Báo mất thẻ" data-confirm-danger>
                                <input type="hidden" name="action" value="reportLost">
                                <input type="hidden" name="cardId" value="${c.card_id}">
                                <button type="submit" class="link danger">Báo mất thẻ</button>
                            </form>
                        </c:when>
                        <c:otherwise><span class="muted">–</span></c:otherwise>
                    </c:choose>
                </td>
            </tr>
            </c:forEach>
            <c:if test="${empty cards}"><tr><td colspan="5" class="empty">Bạn chưa có thẻ. Khi đặt tủ, chọn Thẻ từ rồi đăng ký thẻ tại hộp bằng mã đăng ký.</td></tr></c:if>
        </table>
        </div>
    </section>

    <%-- 3. fingerprints, one per box --%>
    <section class="ml-section" id="fingerprints" aria-labelledby="hFp">
        <h3 id="hFp">Vân tay</h3>
        <p class="hint">Vân tay đăng ký một lần trên mỗi hộp và dùng lại cho các lượt sau.</p>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Hộp tủ</th><th>Vị trí mẫu</th><th>Đăng ký lúc</th><th>Thao tác</th></tr>
            <c:forEach var="f" items="${fingerprints}">
            <tr>
                <td><code><c:out value="${f.device_code}"/></code></td>
                <td class="num"><c:out value="${f.sensor_slot}"/></td>
                <td><ui:dt value="${f.created_at}"/></td>
                <td class="ops">
                    <form method="post" action="${ctx}/MyLockerController" data-confirm="Xóa vân tay trên hộp <c:out value='${f.device_code}'/>? Lần sau chọn Vân tay phải đăng ký lại." data-confirm-ok="Xóa vân tay" data-confirm-danger>
                        <input type="hidden" name="action" value="deleteFingerprint">
                        <input type="hidden" name="fpId" value="${f.fp_id}">
                        <button type="submit" class="link danger">Xóa</button>
                    </form>
                </td>
            </tr>
            </c:forEach>
            <c:if test="${empty fingerprints}"><tr><td colspan="4" class="empty">Bạn chưa đăng ký vân tay trên hộp nào.</td></tr></c:if>
        </table>
        </div>
    </section>

    <%-- 4. history --%>
    <section class="ml-section" id="history" aria-labelledby="hHistory">
        <h3 id="hHistory">Lịch sử gửi đồ</h3>
        <div class="tablewrap">
        <table class="grid">
            <tr><th>Ngăn</th><th>Dãy tủ</th><th>Gói</th><th>Cách mở</th><th>Thanh toán</th><th>Trạng thái</th><th>Đặt lúc</th><th>Kết thúc</th></tr>
            <c:forEach var="d" items="${history}">
            <tr>
                <td><b><c:out value="${d.slotCode}"/></b></td>
                <td><c:out value="${d.bankCode}"/></td>
                <td><c:out value="${d.planName}"/></td>
                <td><c:out value="${d.openMethod == 'CARD' ? 'Thẻ từ' : d.openMethod == 'FINGERPRINT' ? 'Vân tay' : 'Mật mã'}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${d.paidAmount == 0}"><span class="tag">Miễn phí</span></c:when>
                        <c:when test="${d.status == 'NO_SHOW'}">
                            <span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> đ</span>
                            <c:set var="refund" value="${refunds[d.depositId]}"/>
                            <c:choose>
                                <c:when test="${empty refund}"></c:when>
                                <c:when test="${refund == 0}"><span class="muted">không đến, không hoàn</span></c:when>
                                <c:otherwise><span class="muted">đã hoàn <fmt:formatNumber value="${refund}" groupingUsed="true"/> đ</span></c:otherwise>
                            </c:choose>
                        </c:when>
                        <c:when test="${d.status == 'CANCELLED'}">
                            <span class="muted">Đã hoàn <span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> đ</span></span>
                        </c:when>
                        <c:otherwise><span class="money"><fmt:formatNumber value="${d.paidAmount}" groupingUsed="true"/> đ</span></c:otherwise>
                    </c:choose>
                </td>
                <td><ui:status value="${d.status}" kind="deposit"/></td>
                <td><ui:dt value="${d.reservedAt}"/></td>
                <td><ui:dt value="${d.endedAt}"/></td>
            </tr>
            </c:forEach>
            <c:if test="${empty history}"><tr><td colspan="8" class="empty">Chưa có lượt gửi nào đã kết thúc.</td></tr></c:if>
        </table>
        </div>
    </section>
</main>
<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/my-locker.js"></script>
</body>
</html>
