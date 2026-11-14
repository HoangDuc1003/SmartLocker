<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Access denied · Smart Locker</title>
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
                <h2>Page not found (404)</h2>
                <p>There is no page or resource at this address.</p>
            </c:when>
            <c:otherwise>
                <h2>Access denied (403)</h2>
                <p>Your current role is not allowed to open this page. Contact an administrator if you need access.</p>
            </c:otherwise>
        </c:choose>
        <div class="actions">
            <c:choose>
                <c:when test="${not empty sessionScope.LOGIN_USER}">
                    <a class="btn" href="${pageContext.request.contextPath}/LockerMapController">Back to the locker map</a>
                </c:when>
                <c:otherwise>
                    <a class="btn" href="${pageContext.request.contextPath}/LockerMapController?login=1">Sign in</a>
                </c:otherwise>
            </c:choose>
        </div>
    </div>
</main>
</body>
</html>
