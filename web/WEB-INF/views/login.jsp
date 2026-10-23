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
<div class="login-split">
    <%@ include file="common/loginAside.jspf" %>

    <main class="login-main">
        <div class="login-tools">
            <button type="button" class="icon-btn theme-toggle" aria-label="Đổi nền sáng / tối" title="Đổi nền sáng / tối">
                <svg class="ico ico-moon" viewBox="0 0 24 24" aria-hidden="true"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
                <svg class="ico ico-sun" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
            </button>
        </div>
        <form class="login-box" method="post" action="${pageContext.request.contextPath}/LoginController">
            <h1>Đăng nhập</h1>
            <p class="sub">Học kỳ FALL2026. Đăng nhập để đặt ngăn và mở tủ.</p>

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
                   autocomplete="username" autocapitalize="none" spellcheck="false" autofocus required>

            <label for="password">Mật khẩu</label>
            <div class="pw-field">
                <input type="password" id="password" name="password" autocomplete="current-password" required>
                <button type="button" class="pw-toggle" data-pw-toggle="password" aria-pressed="false" aria-label="Hiện mật khẩu" title="Hiện mật khẩu">
                    <svg class="ico ico-eye" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>
                    <svg class="ico ico-eye-off" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 3l18 18"/><path d="M10.6 5.1A10 10 0 0 1 12 5c6.4 0 10 7 10 7a17 17 0 0 1-3.2 4M6.6 6.6A17 17 0 0 0 2 12s3.6 7 10 7a9.6 9.6 0 0 0 5.4-1.6"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/></svg>
                </button>
            </div>

            <button type="submit" class="login-submit">Đăng nhập</button>
            <p class="login-alt">Chưa có tài khoản? <a href="${pageContext.request.contextPath}/RegisterController">Đăng ký</a></p>
        </form>
    </main>
</div>
<script src="${pageContext.request.contextPath}/js/app.js"></script>
</body>
</html>
