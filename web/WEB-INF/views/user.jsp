<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<c:set var="activeNav" value="users"/>
<%--
  Users. Skeleton: the frame and the menu work, the rest is yours.
  Controller: UserController
  Attributes it sets: list: items (User), total, page, pages, q, role, status, roles. form: item, isNew, roles (only the ones the user may give), areas, isSelf, error
  Filters: keyword, role, status
  Show Lock, Reset password and Delete only when the signed-in user outranks the row (the controller sets canManage on each row or a Set of ids).
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Users</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add user' : 'Edit user'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/UserController">
        <input type="hidden" name="action" value="save">
        <input type="hidden" name="id" value="${item.userId}">

        <label for="username">Username *</label>
        <input type="text" id="username" name="username" value="<c:out value='${item.username}'/>"
               required minlength="3" maxlength="50" pattern="[A-Za-z0-9_.]{3,50}"
               title="3 to 50 characters: letters without accents, digits, _ and ."
               ${!isNew ? 'readonly' : ''}>

        <label for="fullName">Full name *</label>
        <input type="text" id="fullName" name="fullName" value="<c:out value='${item.fullName}'/>"
               required minlength="2" maxlength="80">

        <label for="email">Email *</label>
        <input type="email" id="email" name="email" value="<c:out value='${item.email}'/>"
               required maxlength="80" placeholder="name@example.com">

        <label for="phone">Phone</label>
        <input type="text" id="phone" name="phone" value="<c:out value='${item.phone}'/>"
               maxlength="20" placeholder="0xxxxxxxxx">

        <label for="roleName">Role *</label>
        <select id="roleName" name="roleName" required>
            <option value="">-- Choose a role --</option>
            <c:forEach var="r" items="${roles}">
                <option value="${r.role_name}" ${item.roleName == r.role_name ? 'selected' : ''}><c:out value="${r.role_name}"/></option>
            </c:forEach>
        </select>

        <label for="areaId">Area</label>
        <select id="areaId" name="areaId">
            <option value="">-- None / All areas --</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${item.areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> - <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>

        <label for="status">Status *</label>
        <select id="status" name="status" required>
            <option value="ACTIVE" ${item.status == 'ACTIVE' ? 'selected' : ''}>ACTIVE</option>
            <option value="LOCKED" ${item.status == 'LOCKED' ? 'selected' : ''}>LOCKED</option>
            <option value="DISABLED" ${item.status == 'DISABLED' ? 'selected' : ''}>DISABLED</option>
        </select>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/UserController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Users (${total})</h2>

    <form class="filter" method="get" action="${ctx}/UserController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Username, full name or email">
        <select name="role">
            <option value="">-- All roles --</option>
            <c:forEach var="r" items="${roles}">
                <option value="${r.role_name}" ${role == r.role_name ? 'selected' : ''}><c:out value="${r.role_name}"/></option>
            </c:forEach>
        </select>
        <select name="status">
            <option value="">-- All statuses --</option>
            <option value="ACTIVE" ${status == 'ACTIVE' ? 'selected' : ''}>ACTIVE</option>
            <option value="LOCKED" ${status == 'LOCKED' ? 'selected' : ''}>LOCKED</option>
            <option value="DISABLED" ${status == 'DISABLED' ? 'selected' : ''}>DISABLED</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/UserController">Clear</a>
        <c:if test="${perms.contains('USER:WRITE')}">
            <a class="btn" href="${ctx}/UserController?action=new">Add user</a>
        </c:if>
        <c:url var="exportUrl" value="/UserController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="role" value="${role}"/>
            <c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Username</th><th>Full name</th><th>Email</th><th>Role</th><th>Area</th><th class="r">Balance</th><th class="c">Status</th><th>Actions</th></tr>
        <c:forEach var="x" items="${items}">
        <tr class="${x.status == 'LOCKED' ? 'locked' : ''}">
            <td>${x.userId}</td>
            <td><b><c:out value="${x.username}"/></b></td>
            <td><c:out value="${x.fullName}"/></td>
            <td><c:out value="${x.email}"/></td>
            <td><c:out value="${x.roleName}"/></td>
            <td><c:out value="${x.areaCode != null ? x.areaCode : '-'}"/></td>
            <td class="r" style="font-weight:600; color:#2e7d32;"><fmt:formatNumber value="${x.balance}" type="number" groupingUsed="true"/> VND</td>
            <td class="c">${x.status}</td>
            <td class="ops">
                <c:if test="${LOGIN_USER.roleName == 'ADMIN'}">
                    <form method="post" action="${ctx}/UserController" style="display:inline-flex; gap:3px; align-items:center; margin-right:4px;">
                        <input type="hidden" name="action" value="grantBalance">
                        <input type="hidden" name="id" value="${x.userId}">
                        <input type="number" name="amount" value="50000" step="10000" min="1000" style="width:75px; padding:2px 4px; font-size:11px; border:1px solid #ccc; border-radius:3px;" title="Amount to add">
                        <button type="submit" class="btn" style="padding:2px 6px; font-size:11px; background:#2e7d32; color:#fff; border:none; border-radius:3px; cursor:pointer;" onclick="return confirm('Add funds to ${x.username}?');">+ Add funds</button>
                    </form>
                </c:if>
                <c:set var="canAct" value="${LOGIN_USER.roleName == 'ADMIN' or x.roleRank > LOGIN_USER.roleRank}"/>
                <c:if test="${perms.contains('USER:WRITE') and (canAct or x.userId == LOGIN_USER.userId)}">
                    <a href="${ctx}/UserController?action=edit&amp;id=${x.userId}">Edit</a>
                </c:if>
                <c:if test="${perms.contains('USER:WRITE') and canAct and x.userId != LOGIN_USER.userId}">
                    <c:choose>
                        <c:when test="${x.status == 'ACTIVE'}">
                            <form method="post" action="${ctx}/UserController" style="display:inline;" onsubmit="return confirm('Lock this user?');">
                                <input type="hidden" name="action" value="lock">
                                <input type="hidden" name="id" value="${x.userId}">
                                <button type="submit" class="link danger">Lock</button>
                            </form>
                        </c:when>
                        <c:when test="${x.status == 'LOCKED'}">
                            <form method="post" action="${ctx}/UserController" style="display:inline;">
                                <input type="hidden" name="action" value="unlock">
                                <input type="hidden" name="id" value="${x.userId}">
                                <button type="submit" class="link">Unlock</button>
                            </form>
                        </c:when>
                    </c:choose>
                    <form method="post" action="${ctx}/UserController" style="display:inline;" onsubmit="return confirm('Reset password to 123456?');">
                        <input type="hidden" name="action" value="reset">
                        <input type="hidden" name="id" value="${x.userId}">
                        <button type="submit" class="link">Reset PW</button>
                    </form>
                    <form method="post" action="${ctx}/UserController" style="display:inline;" onsubmit="return confirm('Delete this user?');">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${x.userId}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="8" class="c">No user matches the filter</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/UserController">
                        <c:param name="q" value="${q}"/>
                        <c:param name="role" value="${role}"/>
                        <c:param name="status" value="${status}"/>
                        <c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</c:otherwise>

</c:choose>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
