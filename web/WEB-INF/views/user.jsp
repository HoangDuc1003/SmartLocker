<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="users"/>
<%--
  Users. Controller: UserController
  Attributes it sets: list: items (User), total, page, pages, q, role, status, roles. form: item, isNew, roles (only the ones the user may give), areas, isSelf, error
  Lock, Reset password and Delete show only when the signed-in user outranks the row.
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Người dùng · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Thêm người dùng' : 'Sửa người dùng'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/UserController">
        <input type="hidden" name="action" value="save">
        <input type="hidden" name="id" value="${item.userId}">

        <label for="username">Tên đăng nhập <span class="req">*</span></label>
        <input type="text" id="username" name="username" value="<c:out value='${item.username}'/>"
               required minlength="3" maxlength="50" pattern="[A-Za-z0-9_.]{3,50}"
               title="3 đến 50 ký tự: chữ không dấu, số, _ và ." ${!isNew ? 'readonly' : ''}>

        <label for="fullName">Họ và tên <span class="req">*</span></label>
        <input type="text" id="fullName" name="fullName" value="<c:out value='${item.fullName}'/>" required minlength="2" maxlength="80">

        <label for="email">Email <span class="req">*</span></label>
        <input type="email" id="email" name="email" value="<c:out value='${item.email}'/>" required maxlength="80" placeholder="ten@vidu.com">

        <label for="phone">Số điện thoại</label>
        <input type="text" id="phone" name="phone" value="<c:out value='${item.phone}'/>" maxlength="20" placeholder="0xxxxxxxxx" inputmode="tel">

        <label for="roleName">Vai trò <span class="req">*</span></label>
        <select id="roleName" name="roleName" required>
            <option value="">Chọn vai trò</option>
            <c:forEach var="r" items="${roles}">
                <option value="<c:out value='${r.role_name}'/>" ${item.roleName == r.role_name ? 'selected' : ''}><c:out value="${r.role_name}"/></option>
            </c:forEach>
        </select>

        <label for="areaId">Khu vực</label>
        <select id="areaId" name="areaId">
            <option value="">Không giới hạn / tất cả khu vực</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${item.areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> – <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>

        <label for="status">Trạng thái <span class="req">*</span></label>
        <select id="status" name="status" required>
            <option value="ACTIVE" ${item.status == 'ACTIVE' ? 'selected' : ''}>Hoạt động</option>
            <option value="LOCKED" ${item.status == 'LOCKED' ? 'selected' : ''}>Đã khóa</option>
            <option value="DISABLED" ${item.status == 'DISABLED' ? 'selected' : ''}>Vô hiệu</option>
        </select>

        <div class="actions">
            <button type="submit">Lưu</button>
            <a class="btn ghost" href="${ctx}/UserController">Hủy</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Người dùng <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('USER:WRITE')}">
            <a class="btn" href="${ctx}/UserController?action=new">Thêm người dùng</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/UserController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Tên đăng nhập, họ tên hoặc email" aria-label="Tìm kiếm">
        <select name="role" aria-label="Vai trò">
            <option value="">Tất cả vai trò</option>
            <c:forEach var="r" items="${roles}">
                <option value="<c:out value='${r.role_name}'/>" ${role == r.role_name ? 'selected' : ''}><c:out value="${r.role_name}"/></option>
            </c:forEach>
        </select>
        <select name="status" aria-label="Trạng thái">
            <option value="">Tất cả trạng thái</option>
            <option value="ACTIVE" ${status == 'ACTIVE' ? 'selected' : ''}>Hoạt động</option>
            <option value="LOCKED" ${status == 'LOCKED' ? 'selected' : ''}>Đã khóa</option>
            <option value="DISABLED" ${status == 'DISABLED' ? 'selected' : ''}>Vô hiệu</option>
        </select>
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/UserController">Xóa lọc</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/UserController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="role" value="${role}"/>
            <c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Xuất CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Tên đăng nhập</th><th>Họ tên</th><th>Email</th><th>Vai trò</th><th>Khu vực</th><th class="r">Số dư</th><th>Trạng thái</th><th>Thao tác</th></tr>
        <c:forEach var="x" items="${items}">
        <tr class="${x.status == 'LOCKED' ? 'locked' : ''}">
            <td class="num">${x.userId}</td>
            <td><b><c:out value="${x.username}"/></b></td>
            <td><c:out value="${x.fullName}"/></td>
            <td><c:out value="${x.email}"/></td>
            <td><c:out value="${x.roleName}"/></td>
            <td><c:out value="${x.areaCode != null ? x.areaCode : '–'}"/></td>
            <td class="r"><span class="money"><fmt:formatNumber value="${x.balance}" type="number" groupingUsed="true"/> đ</span></td>
            <td><ui:status value="${x.status}"/></td>
            <td class="ops">
                <c:set var="canAct" value="${LOGIN_USER.roleName == 'ADMIN' or x.roleRank > LOGIN_USER.roleRank}"/>
                <c:if test="${perms.contains('USER:WRITE') and (canAct or x.userId == LOGIN_USER.userId)}">
                    <a href="${ctx}/UserController?action=edit&amp;id=${x.userId}">Sửa</a>
                </c:if>
                <c:if test="${perms.contains('USER:WRITE') and canAct and x.userId != LOGIN_USER.userId}">
                    <c:choose>
                        <c:when test="${x.status == 'ACTIVE'}">
                            <form method="post" action="${ctx}/UserController" data-confirm="Khóa tài khoản này?" data-confirm-danger>
                                <input type="hidden" name="action" value="lock">
                                <input type="hidden" name="id" value="${x.userId}">
                                <button type="submit" class="link danger">Khóa</button>
                            </form>
                        </c:when>
                        <c:when test="${x.status == 'LOCKED'}">
                            <form method="post" action="${ctx}/UserController">
                                <input type="hidden" name="action" value="unlock">
                                <input type="hidden" name="id" value="${x.userId}">
                                <button type="submit" class="link">Mở khóa</button>
                            </form>
                        </c:when>
                    </c:choose>
                    <form method="post" action="${ctx}/UserController" data-confirm="Đặt lại mật khẩu thành 123456?">
                        <input type="hidden" name="action" value="reset">
                        <input type="hidden" name="id" value="${x.userId}">
                        <button type="submit" class="link">Đặt lại mật khẩu</button>
                    </form>
                    <form method="post" action="${ctx}/UserController" data-confirm="Xóa người dùng này?" data-confirm-danger>
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${x.userId}">
                        <button type="submit" class="link danger">Xóa</button>
                    </form>
                </c:if>
                <c:if test="${LOGIN_USER.roleName == 'ADMIN'}">
                    <%-- the name is not printed inside the inline script: a quote in it would break out of the string --%>
                    <form method="post" action="${ctx}/UserController" data-confirm="Cộng số tiền này vào ví của người dùng?">
                        <input type="hidden" name="action" value="grantBalance">
                        <input type="hidden" name="id" value="${x.userId}">
                        <input type="number" name="amount" value="50000" step="1" min="1000" aria-label="Số tiền cộng cho ${x.userId}">
                        <button type="submit" class="btn--sm ghost">Cộng tiền</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="9" class="empty">Không có người dùng nào khớp bộ lọc.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
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
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
