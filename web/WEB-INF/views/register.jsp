<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Đăng ký · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body class="login-page">
<main class="login-stack">
    <form class="login-box" method="post" action="${pageContext.request.contextPath}/RegisterController">
        <h1>Tạo tài khoản</h1>
        <p class="sub">Tài khoản mới là tài khoản người dùng tủ.</p>

        <%-- the controller sets error, and gives back what was typed so the form is not emptied --%>
        <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

        <label for="username">Tên đăng nhập</label>
        <input type="text" id="username" name="username" value="<c:out value='${username}'/>"
               required minlength="3" maxlength="50" pattern="[A-Za-z0-9_.]{3,50}" autocomplete="username"
               title="3 đến 50 ký tự: chữ không dấu, số, _ và ." aria-describedby="usernameHint">
        <p class="hint" id="usernameHint">3–50 ký tự: chữ không dấu, số, dấu _ và dấu chấm.</p>

        <label for="fullName">Họ và tên</label>
        <input type="text" id="fullName" name="fullName" value="<c:out value='${fullName}'/>"
               required minlength="2" maxlength="80" autocomplete="name">

        <label for="password">Mật khẩu</label>
        <input type="password" id="password" name="password" required minlength="6" autocomplete="new-password"
               aria-describedby="passwordHint">
        <p class="hint" id="passwordHint">Tối thiểu 6 ký tự.</p>

        <label for="confirm">Nhập lại mật khẩu</label>
        <input type="password" id="confirm" name="confirm" required minlength="6" autocomplete="new-password">

        <button type="submit">Đăng ký</button>
        <p class="hint" style="margin-top:14px">Đã có tài khoản? <a href="${pageContext.request.contextPath}/LoginController">Đăng nhập</a></p>
    </form>
</main>
</body>
</html>
