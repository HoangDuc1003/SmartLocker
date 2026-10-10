<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="cards"/>
<%--
  Cards. Skeleton: the frame and the menu work, the rest is yours.
  Controller: UserCardController
  Attributes it sets: list: items (UserCard), total, page, pages, q, status. form: item, isNew, users, error
  Filters: keyword (uid or username), status
  A LOST or BLOCKED card gets a Replace button that asks for the new uid.
  Copy the pattern of lockerSlot.jsp: the choose/when for list and form, the filter form, c:forEach, c:url for the pager.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Cards</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
    <h2>Cards</h2>

    <%-- TODO 1: the filter form (class="filter"), method get, keep the values with <c:out> --%>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Card uid</th><th>User</th><th>Status</th><th>Issued</th><th>Lost at</th><th>Actions</th></tr>
        <%-- TODO 2: <c:forEach var="x" items="${items}"> one row per item, <c:out> for every text --%>
        <c:if test="${empty items}"><tr><td colspan="7" class="c">Nothing to show</td></tr></c:if>
    </table>
    </div>

    <%-- TODO 3: the pager (class="pager") and, where the controller has a form mode, the form (class="form") --%>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
