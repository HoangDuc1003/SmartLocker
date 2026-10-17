<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="plans"/>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Gói gửi đồ · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Thêm gói gửi đồ' : 'Sửa gói gửi đồ'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/StoragePlanController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.planId}">

        <label for="planName">Tên gói <span class="req">*</span></label>
        <input type="text" id="planName" name="planName" value="<c:out value='${item.planName}'/>"
               required maxlength="40" placeholder="Ví dụ: Gói 2 giờ">

        <label for="durationMin">Thời lượng (phút) <span class="req">*</span></label>
        <input type="number" id="durationMin" name="durationMin" value="${item.durationMin}" required min="1" max="1440">

        <label for="graceMin">Thời gian ân hạn (phút) <span class="req">*</span></label>
        <input type="number" id="graceMin" name="graceMin" value="${item.graceMin}" required min="0" max="120"
               aria-describedby="graceHint">
        <p class="hint" id="graceHint">Số phút được trễ sau hạn trả trước khi bị tính quá hạn.</p>

        <label for="price">Giá (đồng) <span class="req">*</span></label>
        <input type="number" id="price" name="price" value="${item.price}" required min="0">

        <label class="check">
            <input type="checkbox" name="isActive" value="true" ${item.active ? 'checked' : ''}>
            Đang mở bán
        </label>

        <div class="actions">
            <button type="submit">Lưu</button>
            <a class="btn ghost" href="${ctx}/StoragePlanController">Hủy</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Gói gửi đồ <span class="count">(${total})</span></h2>
        <div class="filter" style="margin:0">
            <a class="btn ghost" href="${ctx}/StoragePlanController?action=export">Xuất CSV</a>
            <c:if test="${perms.contains('STORAGEPLAN:WRITE')}">
                <a class="btn" href="${ctx}/StoragePlanController?action=new">Thêm gói</a>
            </c:if>
        </div>
    </div>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Tên gói</th><th class="r">Thời lượng</th><th class="r">Ân hạn</th><th class="r">Giá</th><th>Trạng thái</th><th>Thao tác</th></tr>
        <c:forEach var="p" items="${items}">
        <tr class="${!p.active ? 'locked' : ''}">
            <td class="num">${p.planId}</td>
            <td><b><c:out value="${p.planName}"/></b></td>
            <td class="r num">${p.durationMin} phút</td>
            <td class="r num">${p.graceMin} phút</td>
            <td class="r"><span class="money"><fmt:formatNumber value="${p.price}" groupingUsed="true"/> đ</span></td>
            <td><ui:status value="${p.active ? 'ACTIVE' : 'INACTIVE'}"/></td>
            <td class="ops">
                <c:if test="${perms.contains('STORAGEPLAN:WRITE')}">
                    <a href="${ctx}/StoragePlanController?action=edit&amp;id=${p.planId}">Sửa</a>
                    <form method="post" action="${ctx}/StoragePlanController" data-confirm="Xóa gói này?" data-confirm-danger>
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${p.planId}">
                        <button type="submit" class="link danger">Xóa</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">Chưa có gói nào.</td></tr></c:if>
    </table>
    </div>
</c:otherwise>

</c:choose>
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
