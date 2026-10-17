<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="slots"/>
<%-- The model of every CRUD page. One JSP, two modes: LockerSlotController sets mode = list or form.
     Attributes of the list: items, total, page, pages, q, bankId, status, banks.
     Attributes of the form: item, isNew, banks, and error after a failed save. --%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Ngăn tủ · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Thêm ngăn tủ' : 'Sửa ngăn tủ'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <%-- the browser checks save a round trip, the controller repeats every rule --%>
    <form class="form" method="post" action="${ctx}/LockerSlotController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.slotId}">

        <label for="bankId">Dãy tủ <span class="req">*</span></label>
        <select id="bankId" name="bankId" required>
            <option value="">Chọn dãy tủ</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${item.bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>

        <label for="slotCode">Mã ngăn <span class="req">*</span></label>
        <input type="text" id="slotCode" name="slotCode" value="<c:out value='${item.slotCode}'/>"
               required maxlength="20" pattern="[A-Za-z0-9_-]{1,20}" title="1 đến 20 chữ cái, số, - hoặc _" placeholder="A01">

        <label for="sizeCode">Kích cỡ <span class="req">*</span></label>
        <select id="sizeCode" name="sizeCode" required>
            <option value="S" ${item.sizeCode == 'S' ? 'selected' : ''}>S – nhỏ</option>
            <option value="M" ${item.sizeCode == 'M' ? 'selected' : ''}>M – vừa</option>
            <option value="L" ${item.sizeCode == 'L' ? 'selected' : ''}>L – lớn (cao gấp đôi trên sơ đồ)</option>
        </select>

        <label for="sizeCm">Kích thước (cm)</label>
        <input type="text" id="sizeCm" name="sizeCm" value="<c:out value='${item.sizeCm}'/>" maxlength="20" placeholder="30x30x45">

        <label for="status">Trạng thái <span class="req">*</span></label>
        <select id="status" name="status" required>
            <option value="AVAILABLE" ${item.status == 'AVAILABLE' ? 'selected' : ''}>Trống</option>
            <option value="RESERVED" ${item.status == 'RESERVED' ? 'selected' : ''}>Đã đặt</option>
            <option value="OCCUPIED" ${item.status == 'OCCUPIED' ? 'selected' : ''}>Đang dùng</option>
            <option value="MAINTENANCE" ${item.status == 'MAINTENANCE' ? 'selected' : ''}>Bảo trì</option>
        </select>

        <div class="actions">
            <button type="submit">Lưu</button>
            <a class="btn ghost" href="${ctx}/LockerSlotController">Hủy</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Ngăn tủ <span class="count">(${total})</span></h2>
        <%-- the controls of a role without WRITE are not drawn; the filter would refuse the request anyway --%>
        <c:if test="${perms.contains('LOCKERSLOT:WRITE')}"><a class="btn" href="${ctx}/LockerSlotController?action=new">Thêm ngăn</a></c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/LockerSlotController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Mã ngăn" aria-label="Mã ngăn">
        <select name="bankId" aria-label="Dãy tủ">
            <option value="">Tất cả dãy tủ</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>
        <select name="status" aria-label="Trạng thái">
            <option value="">Tất cả trạng thái</option>
            <option value="AVAILABLE" ${status == 'AVAILABLE' ? 'selected' : ''}>Trống</option>
            <option value="RESERVED" ${status == 'RESERVED' ? 'selected' : ''}>Đã đặt</option>
            <option value="OCCUPIED" ${status == 'OCCUPIED' ? 'selected' : ''}>Đang dùng</option>
            <option value="MAINTENANCE" ${status == 'MAINTENANCE' ? 'selected' : ''}>Bảo trì</option>
        </select>
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/LockerSlotController">Xóa lọc</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/LockerSlotController">
            <c:param name="action" value="export"/><c:param name="q" value="${q}"/>
            <c:param name="bankId" value="${bankId}"/><c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Xuất CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Dãy tủ</th><th>Ngăn</th><th>Cỡ</th><th>Kích thước (cm)</th><th>Trạng thái</th><th>Thao tác</th></tr>
        <c:forEach var="s" items="${items}">
        <tr class="${s.status == 'MAINTENANCE' ? 'locked' : ''}">
            <td class="num">${s.slotId}</td>
            <td><c:out value="${s.bankCode}"/></td>
            <td><b><c:out value="${s.slotCode}"/></b></td>
            <td><c:out value="${s.sizeCode}"/></td>
            <td><c:out value="${s.sizeCm}"/></td>
            <td><ui:status value="${s.status}"/></td>
            <td class="ops">
                <c:if test="${perms.contains('SLOTSTATUS:WRITE')}">
                    <form method="post" action="${ctx}/LockerSlotController">
                        <input type="hidden" name="action" value="status">
                        <input type="hidden" name="id" value="${s.slotId}">
                        <select name="status" aria-label="Trạng thái mới của ngăn <c:out value="${s.slotCode}"/>" required>
                            <option value="AVAILABLE" ${s.status == 'AVAILABLE' ? 'selected' : ''}>Trống</option>
                            <option value="RESERVED" ${s.status == 'RESERVED' ? 'selected' : ''}>Đã đặt</option>
                            <option value="OCCUPIED" ${s.status == 'OCCUPIED' ? 'selected' : ''}>Đang dùng</option>
                            <option value="MAINTENANCE" ${s.status == 'MAINTENANCE' ? 'selected' : ''}>Bảo trì</option>
                        </select>
                        <button type="submit" class="btn--sm ghost">Cập nhật</button>
                    </form>
                </c:if>
                <c:if test="${perms.contains('LOCKERSLOT:WRITE')}">
                    <a href="${ctx}/LockerSlotController?action=edit&amp;id=${s.slotId}">Sửa</a>
                    <%-- never print data inside inline JavaScript: a quote in the data would break out of the string --%>
                    <form method="post" action="${ctx}/LockerSlotController" data-confirm="Xóa ngăn tủ này?" data-confirm-danger>
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${s.slotId}">
                        <button type="submit" class="link danger">Xóa</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">Không có ngăn nào khớp bộ lọc.</td></tr></c:if>
    </table>
    </div>

    <%-- c:url encodes every value, so a keyword with & or a space cannot break the link --%>
    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/LockerSlotController">
                        <c:param name="q" value="${q}"/><c:param name="bankId" value="${bankId}"/>
                        <c:param name="status" value="${status}"/><c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</c:otherwise>

</c:choose>
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
