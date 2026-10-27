<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Không truy cập được · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%-- the menu only for a signed-in user; a guest sees the message alone --%>
<c:if test="${not empty sessionScope.LOGIN_USER}">
    <%@ include file="common/nav.jspf" %>
</c:if>
<main id="main" class="wrap">
    <div class="panel denied">
        <c:choose>
            <c:when test="${requestScope['javax.servlet.error.status_code'] == 404}">
                <h2>Không tìm thấy trang (404)</h2>
                <p>Địa chỉ này không có trang hoặc tài nguyên nào.</p>
            </c:when>
            <c:otherwise>
                <h2>Không có quyền truy cập (403)</h2>
                <p>Vai trò hiện tại của bạn không được phép mở trang này. Hãy liên hệ quản trị viên nếu bạn cần quyền.</p>
            </c:otherwise>
        </c:choose>
        <div class="actions">
            <c:choose>
                <c:when test="${not empty sessionScope.LOGIN_USER}">
                    <a class="btn" href="${pageContext.request.contextPath}/LockerMapController">Về sơ đồ tủ</a>
                </c:when>
                <c:otherwise>
                    <a class="btn" href="${pageContext.request.contextPath}/LockerMapController?login=1">Đăng nhập</a>
                </c:otherwise>
            </c:choose>
        </div>
    </div>
</main>
</body>
</html>
