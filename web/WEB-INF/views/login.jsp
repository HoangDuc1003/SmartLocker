<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Đăng nhập · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body class="login-page">
<main class="login-stack">
    <div class="login-tools">
        <button type="button" class="icon-btn theme-toggle" aria-label="Đổi nền sáng / tối" title="Đổi nền sáng / tối">
            <svg class="ico ico-moon" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
            <svg class="ico ico-sun" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
        </button>
    </div>
    <form class="login-box" method="post" action="${pageContext.request.contextPath}/LoginController">
        <span class="side-brand__mark"><svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg></span>
        <h1>Smart Locker</h1>
        <p class="sub">Học kỳ FALL2026. Đăng nhập để tiếp tục.</p>

        <%-- set by LoginController after a failed sign in --%>
        <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>
        <%-- set by RegisterController after a successful registration --%>
        <c:if test="${not empty sessionScope.flash}">
            <div class="flash ${sessionScope.flashBad ? 'bad' : ''}" role="status"><c:out value="${sessionScope.flash}"/></div>
            <c:remove var="flash" scope="session"/>
            <c:remove var="flashBad" scope="session"/>
        </c:if>

        <label for="username">Tên đăng nhập</label>
        <input type="text" id="username" name="username" value="<c:out value='${username}'/>"
               autocomplete="username" autofocus required>

        <label for="password">Mật khẩu</label>
        <input type="password" id="password" name="password" autocomplete="current-password" required>

        <button type="submit">Đăng nhập</button>
        <p class="hint" style="margin-top:14px">Chưa có tài khoản? <a href="${pageContext.request.contextPath}/RegisterController">Đăng ký</a></p>
    </form>
</main>
</body>
</html>
