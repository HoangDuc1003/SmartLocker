<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Not allowed</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%-- web.xml sends 403 and 404 here. The menu is drawn only when somebody is signed in. --%>
<c:if test="${not empty sessionScope.LOGIN_USER}"><%@ include file="common/nav.jspf" %></c:if>
<div class="wrap">
    <div class="denied">
        <c:choose>
            <c:when test="${requestScope['javax.servlet.error.status_code'] == 404}">
                <h2>Page not found</h2>
                <p>There is nothing at this address.</p>
            </c:when>
            <c:otherwise>
                <h2>Access denied</h2>
                <p>Your role does not have the permission to open this page.</p>
            </c:otherwise>
        </c:choose>
        <a class="btn ghost" href="${pageContext.request.contextPath}/LoginController">Back to the start</a>
    </div>
</div>
</body>
</html>
