<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" isErrorPage="true" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Not allowed - Smart Locker</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%-- Menu is included defensively; nav.jspf now handles both guest and logged in users safely --%>
<c:if test="${not empty sessionScope.LOGIN_USER}">
    <%@ include file="common/nav.jspf" %>
</c:if>
<div class="wrap">
    <div class="denied">
        <c:choose>
            <c:when test="${requestScope['javax.servlet.error.status_code'] == 404}">
                <h2>Page not found (404)</h2>
                <p>The requested page or resource was not found at this address.</p>
            </c:when>
            <c:otherwise>
                <h2>Access denied (403)</h2>
                <p>Your current role does not have permission to access this resource.</p>
            </c:otherwise>
        </c:choose>
        <c:choose>
            <c:when test="${not empty sessionScope.LOGIN_USER}">
                <a class="btn ghost" href="${pageContext.request.contextPath}/LockerMapController">Go to Locker map</a>
            </c:when>
            <c:otherwise>
                <a class="btn ghost" href="${pageContext.request.contextPath}/LoginController">Back to Login</a>
            </c:otherwise>
        </c:choose>
    </div>
</div>
</body>
</html>
