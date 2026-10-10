<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Login</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body class="login-page">
<div class="login-stack">
    <form class="login-box" method="post" action="${pageContext.request.contextPath}/LoginController">
        <h1>Smart Locker</h1>
        <p class="sub">Semester FALL2026. Sign in to continue.</p>

        <%-- set by LoginController after a failed sign in --%>
        <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>
        <%-- set by RegisterController after a successful registration --%>
        <c:if test="${not empty sessionScope.flash}">
            <div class="flash" style="margin:0 0 12px"><c:out value="${sessionScope.flash}"/></div>
            <c:remove var="flash" scope="session"/>
            <c:remove var="flashBad" scope="session"/>
        </c:if>

        <label for="username">Username</label>
        <input type="text" id="username" name="username" value="<c:out value='${username}'/>" autofocus required>

        <label for="password">Password</label>
        <input type="password" id="password" name="password" required>

        <button type="submit">Sign in</button>
        <p class="hint" style="margin-top:12px">No account yet? <a href="${pageContext.request.contextPath}/RegisterController">Register</a></p>
    </form>
</div>
</body>
</html>
