<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="areas"/>
<%--
  Areas. Controller: LockerAreaController
  Attributes it sets: list: items (LockerArea), total, page, pages, q. form: item, isNew, error
  A delete the database refuses shows its reason in the flash bar.
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Khu vực · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Thêm khu vực' : 'Sửa khu vực'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/LockerAreaController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.areaId}">

        <label for="areaCode">Mã khu vực <span class="req">*</span></label>
        <input type="text" id="areaCode" name="areaCode" value="<c:out value='${item.areaCode}'/>"
               required minlength="2" maxlength="16" pattern="[A-Za-z0-9]{2,16}"
               title="2 đến 16 chữ cái hoặc số" aria-describedby="codeHint" ${!isNew ? 'readonly' : ''}>
        <p class="hint" id="codeHint">2–16 chữ cái không dấu hoặc số. Không đổi được sau khi tạo.</p>

        <label for="name">Tên khu vực <span class="req">*</span></label>
        <input type="text" id="name" name="name" value="<c:out value='${item.name}'/>" required minlength="2" maxlength="80">

        <label for="location">Vị trí</label>
        <input type="text" id="location" name="location" value="<c:out value='${item.location}'/>"
               maxlength="120" placeholder="Ví dụ: Tòa A, tầng 1">

        <fieldset class="field-group">
            <legend>Vị trí trên bản đồ</legend>
            <div class="form-row">
                <div>
                    <label for="latitude">Vĩ độ</label>
                    <input type="text" id="latitude" name="latitude" inputmode="decimal" autocomplete="off"
                           value="<c:out value='${item.latitude}'/>" placeholder="10.841100" aria-describedby="coordHint">
                </div>
                <div>
                    <label for="longitude">Kinh độ</label>
                    <input type="text" id="longitude" name="longitude" inputmode="decimal" autocomplete="off"
                           value="<c:out value='${item.longitude}'/>" placeholder="106.809900" aria-describedby="coordHint">
                </div>
            </div>
            <p class="hint" id="coordHint">Mở Google Maps, bấm chuột phải đúng chỗ đặt tủ rồi bấm dòng số đầu tiên để chép "vĩ độ, kinh độ". Để trống nếu chưa muốn hiện khu này trên bản đồ.</p>
        </fieldset>

        <label class="check">
            <input type="checkbox" name="active" value="true" ${item.active or isNew ? 'checked' : ''}>
            Đang hoạt động (cho phép đặt tủ và gắn dãy tủ)
        </label>

        <div class="actions">
            <button type="submit">Lưu</button>
            <a class="btn ghost" href="${ctx}/LockerAreaController">Hủy</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Khu vực <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('AREA:WRITE')}">
            <a class="btn" href="${ctx}/LockerAreaController?action=new">Thêm khu vực</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/LockerAreaController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Mã, tên hoặc vị trí" aria-label="Tìm kiếm">
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/LockerAreaController">Xóa lọc</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/LockerAreaController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Xuất CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Mã</th><th>Tên</th><th>Vị trí</th><th class="r">Số ngăn</th><th class="r">Người dùng</th><th>Trạng thái</th><th>Thao tác</th></tr>
        <c:forEach var="x" items="${items}">
            <tr class="${not x.active ? 'locked' : ''}">
                <td class="num">${x.areaId}</td>
                <td><b><c:out value="${x.areaCode}"/></b></td>
                <td><c:out value="${x.name}"/></td>
                <td><c:out value="${x.location}"/></td>
                <td class="r num">${x.slotCount}</td>
                <td class="r num">${x.userCount}</td>
                <td><ui:status value="${x.active ? 'ACTIVE' : 'INACTIVE'}"/></td>
                <td class="ops">
                    <c:if test="${perms.contains('AREA:WRITE')}">
                        <a href="${ctx}/LockerAreaController?action=edit&amp;id=${x.areaId}">Sửa</a>
                        <form method="post" action="${ctx}/LockerAreaController" data-confirm="Xóa khu vực này?" data-confirm-danger>
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${x.areaId}">
                            <button type="submit" class="link danger">Xóa</button>
                        </form>
                    </c:if>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="empty">Không có khu vực nào khớp bộ lọc.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/LockerAreaController">
                        <c:param name="q" value="${q}"/>
                        <c:param name="page" value="${p}"/>
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
