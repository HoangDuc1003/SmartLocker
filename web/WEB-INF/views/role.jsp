<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="roles"/>
<%--
  Roles. Skeleton: the frame and the menu work, the rest is yours.
  Controller: RoleController
  Attributes it sets: list: roles (maps with role_id, role_name, rank_no, user_count, perm_count). grid: role, grid (rows of perm_id, resource, action, granted)
  Filters: none
  The permission grid is a table of checkboxes name="permIds" grouped by resource, like rolePermission.jsp of UserManagement.
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Roles</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= PERMISSION GRID ================= --%>
<c:when test="${mode == 'grid'}">
    <h2>Permissions: <c:out value="${roleName}"/></h2>

    <form method="post" action="${ctx}/RoleController">
        <input type="hidden" name="roleId" value="${roleId}">

        <div class="tablewrap" style="margin-bottom:16px;">
        <table class="grid">
            <tr><th>Resource</th><th>Action</th><th class="c">Granted</th></tr>
            <c:forEach var="p" items="${grid}">
                <tr>
                    <td><b><c:out value="${p[1]}"/></b></td>
                    <td><c:out value="${p[2]}"/></td>
                    <td class="c">
                        <c:set var="isCriticalAdminPerm" value="${roleName == 'ADMIN' and p[1] == 'ROLE'}"/>
                        <input type="checkbox" name="permIds" value="${p[0]}"
                               ${p[3] == '1' ? 'checked' : ''}
                               ${isCriticalAdminPerm ? 'disabled title="ADMIN must retain ROLE permissions"' : ''}>
                        <c:if test="${isCriticalAdminPerm}">
                            <input type="hidden" name="permIds" value="${p[0]}">
                        </c:if>
                    </td>
                </tr>
            </c:forEach>
        </table>
        </div>

        <c:if test="${perms.contains('ROLE:WRITE')}">
            <div class="actions">
                <button type="submit">Save permissions</button>
                <a class="btn ghost" href="${ctx}/RoleController">Back to roles</a>
            </div>
        </c:if>
        <c:if test="${not perms.contains('ROLE:WRITE')}">
            <a class="btn ghost" href="${ctx}/RoleController">Back to roles</a>
        </c:if>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Roles</h2>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>Rank</th><th>Role</th><th>Users</th><th>Permissions</th><th>Actions</th></tr>
        <c:forEach var="x" items="${roles}">
            <tr>
                <td>${x.rank_no}</td>
                <td><b><c:out value="${x.role_name}"/></b></td>
                <td>${x.user_count}</td>
                <td>${x.perm_count}</td>
                <td class="ops">
                    <a href="${ctx}/RoleController?id=${x.role_id}">Permissions</a>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty roles}"><tr><td colspan="5" class="c">No roles found</td></tr></c:if>
    </table>
    </div>
</c:otherwise>

</c:choose>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
