<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Register</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body class="login-page">
<div class="login-stack">
    <form class="login-box" method="post" action="${pageContext.request.contextPath}/RegisterController">
        <h1>Create an account</h1>
        <p class="sub">New accounts are Locker Users.</p>

        <%-- the controller sets error, and gives back what was typed so the form is not emptied --%>
        <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

        <label for="username">Username</label>
        <input type="text" id="username" name="username" value="<c:out value='${username}'/>"
               required minlength="3" maxlength="50" pattern="[A-Za-z0-9_.]{3,50}"
               title="3 to 50 characters: letters without accents, digits, _ and .">

        <label for="fullName">Full name</label>
        <input type="text" id="fullName" name="fullName" value="<c:out value='${fullName}'/>" required minlength="2" maxlength="80">

        <label for="password">Password</label>
        <input type="password" id="password" name="password" required minlength="6">

        <label for="confirm">Repeat the password</label>
        <input type="password" id="confirm" name="confirm" required minlength="6">

        <button type="submit">Register</button>
        <p class="hint" style="margin-top:12px">Already registered? <a href="${pageContext.request.contextPath}/LoginController">Sign in</a></p>
    </form>
</div>
</body>
</html>
