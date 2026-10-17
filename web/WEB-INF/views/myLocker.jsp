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
            <article class="panel ml-booking" aria-labelledby="bk${d.depositId}">
                <div class="ml-booking__head">
                    <h3 id="bk${d.depositId}">Ngăn <c:out value="${d.slotCode}"/> <span class="muted"><c:out value="${d.bankCode}"/></span></h3>
                    <span>
                        <ui:status value="${d.status}" kind="deposit"/>
                        <c:if test="${isOverdue}"><ui:status value="OVERDUE"/></c:if>
                    </span>
                </div>

                <c:if test="${d.status == 'RESERVED' and not empty d.holdUntil}">
                    <div>
                        <div class="muted">Giữ chỗ đến <ui:dt value="${d.holdUntil}"/></div>
                        <div class="countdown-big" data-countdown="<c:out value='${d.holdUntil}'/>" data-late-text="Đã hết thời gian giữ chỗ" aria-live="off">&nbsp;</div>
                        <p class="hint">Không đến trong thời gian giữ chỗ sẽ mất 10% (hoàn 90% vào ví).</p>
                    </div>
                </c:if>

                <dl class="kv">
                    <dt>Hộp tủ</dt><dd><code><c:out value="${empty d.deviceCode ? '–' : d.deviceCode}"/></code></dd>
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
                        <c:when test="${d.status == 'RESERVED'}">
                            <form method="post" action="${ctx}/BookingController" data-confirm="Hủy lượt đặt ngăn <c:out value='${d.slotCode}'/>? Số tiền đã trả được hoàn vào ví." data-confirm-ok="Hủy đặt" data-confirm-danger>
                                <input type="hidden" name="action" value="cancel">
                                <input type="hidden" name="depositId" value="${d.depositId}">
                                <input type="hidden" name="back" value="list">
                                <button type="submit" class="ghost">Hủy đặt</button>
                            </form>
                        </c:when>
                        <c:when test="${d.extendCount < 3}">
                            <form method="post" action="${ctx}/BookingController">
                                <input type="hidden" name="action" value="extend">
                                <input type="hidden" name="depositId" value="${d.depositId}">
                                <input type="hidden" name="back" value="list">
                                <select name="minutes" aria-label="Thời gian gia hạn">
                                    <option value="30">+30 phút</option>
                                    <option value="60" selected>+60 phút</option>
                                    <option value="120">+120 phút</option>
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
                            <span class="muted">hoàn <fmt:formatNumber value="${refunds[d.depositId]}" groupingUsed="true"/> đ (giữ 10%)</span>
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
