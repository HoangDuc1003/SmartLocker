<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="commands"/>
<%-- Remote unlock. RemoteCommandController sets items, total, page, pages, status, and slots (for the form).
     The form posts slotId + reason, the same parameters as the slot panel of the locker map. --%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Mở khóa từ xa · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
    <div class="page-head">
        <div>
            <h2>Mở khóa từ xa <span class="count">(${total})</span></h2>
            <p class="sub">Lệnh được xếp hàng và gửi tới bộ điều khiển ở lần heartbeat kế tiếp (khoảng 10 giây), hết hạn sau 2 phút.</p>
        </div>
    </div>

    <c:if test="${perms.contains('COMMAND:WRITE')}">
        <section class="panel" style="margin-bottom:20px">
            <h3>Tạo lệnh mở khóa</h3>
            <form method="post" action="${ctx}/RemoteCommandController" class="grid-3" style="align-items:end">
                <input type="hidden" name="back" value="list">
                <div class="field">
                    <label for="cmdSlot">Ngăn tủ</label>
                    <select id="cmdSlot" name="slotId" required>
                        <option value="">Chọn ngăn</option>
                        <c:forEach var="s" items="${slots}">
                            <option value="${s.slotId}"><c:out value="${s.bankCode}"/> – <c:out value="${s.slotCode}"/></option>
                        </c:forEach>
                    </select>
                </div>
                <div class="field">
                    <label for="cmdReason">Lý do (ít nhất 5 ký tự)</label>
                    <input type="text" id="cmdReason" name="reason" required minlength="5" maxlength="200"
                           placeholder="Ví dụ: Khách quên thẻ, đã xác minh CCCD">
                </div>
                <div>
                    <button type="submit" class="btn--block" data-confirm="Gửi lệnh mở khóa ngăn đã chọn?">Gửi lệnh mở khóa</button>
                </div>
            </form>
        </section>
    </c:if>

    <form class="filter" method="get" action="${ctx}/RemoteCommandController">
        <select name="status" aria-label="Trạng thái">
            <option value="">Tất cả trạng thái</option>
            <option value="PENDING" ${status == 'PENDING' ? 'selected' : ''}>Chờ xử lý</option>
            <option value="SENT" ${status == 'SENT' ? 'selected' : ''}>Đã gửi</option>
            <option value="DONE" ${status == 'DONE' ? 'selected' : ''}>Hoàn tất</option>
            <option value="EXPIRED" ${status == 'EXPIRED' ? 'selected' : ''}>Hết hạn</option>
        </select>
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/RemoteCommandController">Xóa lọc</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Ngăn</th><th>Lý do</th><th>Người yêu cầu</th><th>Trạng thái</th><th>Tạo lúc</th><th>Thực hiện lúc</th></tr>
        <c:forEach var="cmd" items="${items}">
        <tr class="${cmd.status == 'PENDING' ? 'locked' : ''}">
            <td class="num">#${cmd.command_id}</td>
            <td><b><c:out value="${cmd.slot_code}"/></b></td>
            <td><c:out value="${cmd.reason}"/></td>
            <td><c:out value="${cmd.requested_by_name}"/></td>
            <td><ui:status value="${cmd.status}"/></td>
            <td><ui:dt value="${cmd.created_at}"/></td>
            <td><ui:dt value="${cmd.done_at}"/></td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">Chưa có lệnh nào.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/RemoteCommandController">
                        <c:param name="status" value="${status}"/>
                        <c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
