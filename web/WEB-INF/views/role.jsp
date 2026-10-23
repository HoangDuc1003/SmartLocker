<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="roles"/>
<%--
  Roles. Controller: RoleController
  Attributes it sets: list: roles (maps with role_id, role_name, rank_no, user_count, perm_count). grid: role, grid (rows of perm_id, resource, action, granted)
  The permission grid is a table of checkboxes name="permIds" grouped by resource.
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Vai trò &amp; quyền · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= PERMISSION GRID ================= --%>
<c:when test="${mode == 'grid'}">
    <div class="page-head">
        <div>
            <h2>Quyền của vai trò <c:out value="${roleName}"/></h2>
            <p class="sub">READ là xem, WRITE là thêm, sửa, xóa. Vai trò ADMIN luôn giữ quyền ROLE.</p>
        </div>
        <a class="btn ghost" href="${ctx}/RoleController">Quay lại</a>
    </div>

    <form method="post" action="${ctx}/RoleController">
        <input type="hidden" name="roleId" value="${roleId}">

        <div class="tablewrap">
        <table class="grid">
            <tr><th>Tài nguyên</th><th>Hành động</th><th class="c">Được cấp</th></tr>
            <c:forEach var="p" items="${grid}">
                <tr>
                    <td><b><c:out value="${p[1]}"/></b></td>
                    <td><c:out value="${p[2]}"/></td>
                    <td class="c">
                        <c:set var="isCriticalAdminPerm" value="${roleName == 'ADMIN' and p[1] == 'ROLE'}"/>
                        <input type="checkbox" name="permIds" value="${p[0]}" aria-label="<c:out value="${p[1]} ${p[2]}"/>"
                               ${p[3] == '1' ? 'checked' : ''}
                               ${isCriticalAdminPerm or not perms.contains('ROLE:WRITE') ? 'disabled' : ''}
                               ${isCriticalAdminPerm ? 'title="ADMIN phải giữ quyền ROLE"' : ''}>
                        <c:if test="${isCriticalAdminPerm and p[3] == '1'}">
                            <input type="hidden" name="permIds" value="${p[0]}">
                        </c:if>
                    </td>
                </tr>
            </c:forEach>
        </table>
        </div>

        <c:if test="${perms.contains('ROLE:WRITE')}">
            <div class="actions">
                <button type="submit">Lưu quyền</button>
                <a class="btn ghost" href="${ctx}/RoleController">Hủy</a>
            </div>
        </c:if>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Vai trò &amp; quyền</h2>
    </div>

    <div class="tablewrap">
    <table class="grid">
        <tr><th class="r">Cấp</th><th>Vai trò</th><th class="r">Người dùng</th><th class="r">Số quyền</th><th>Thao tác</th></tr>
        <c:forEach var="x" items="${roles}">
            <tr>
                <td class="r num">${x.rank_no}</td>
                <td><b><c:out value="${x.role_name}"/></b></td>
                <td class="r num">${x.user_count}</td>
                <td class="r num">${x.perm_count}</td>
                <td class="ops"><a href="${ctx}/RoleController?id=${x.role_id}">${perms.contains('ROLE:WRITE') ? 'Phân quyền' : 'Xem quyền'}</a></td>
            </tr>
        </c:forEach>
        <c:if test="${empty roles}"><tr><td colspan="5" class="empty">Chưa có vai trò nào.</td></tr></c:if>
    </table>
    </div>
</c:otherwise>

</c:choose>
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
