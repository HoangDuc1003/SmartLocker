<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="topup"/>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<%-- ?panel=1: only the content, drawn by js/glass-panel.js as a glass popup over the users' map --%>
<c:set var="panel" value="${param.panel == '1'}"/>
<c:if test="${not panel}">
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Top up · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
</c:if>
<c:if test="${panel}">
<div class="glass-page">
<%@ include file="common/panel-flash.jspf" %>
</c:if>

<c:if test="${isStaff and not empty param.status}">
    <%-- Staff review of account top-ups: TopupController?status=... from the menu "Top-up review". --%>
    <div class="page-head">
        <div>
            <h2>Top-up review</h2>
            <p class="sub">Approve only after the money has reached the account with the exact transfer note.</p>
        </div>
    </div>
    <form class="filter" method="get" action="${ctx}/TopupController">
        <select name="status" aria-label="Status">
            <option value="ALL" ${status == 'ALL' or empty status ? 'selected' : ''}>All statuses</option>
            <option value="PENDING" ${status == 'PENDING' ? 'selected' : ''}>Pending</option>
            <option value="APPROVED" ${status == 'APPROVED' ? 'selected' : ''}>Approved</option>
            <option value="REJECTED" ${status == 'REJECTED' ? 'selected' : ''}>Rejected</option>
        </select>
        <button type="submit">Filter</button>
    </form>

    <div class="tablewrap">
        <table class="grid">
            <tr><th>#</th><th>User</th><th class="r">Amount</th><th>Transfer note</th><th>Created</th><th>Status</th><th>Actions</th></tr>
            <c:forEach var="req" items="${allRequests}">
                <tr class="${req.status == 'PENDING' ? 'locked' : ''}">
                    <td class="num">${req.requestId}</td>
                    <td><b><c:out value="${req.username}"/></b> <span class="muted"><c:out value="${req.fullName}"/></span></td>
                    <td class="r"><span class="money"><fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> VND</span></td>
                    <td><code><c:out value="${req.transferCode}"/></code></td>
                    <td><ui:dt value="${req.createdAt}"/></td>
                    <td><ui:status value="${req.status}"/></td>
                    <td class="ops">
                        <c:if test="${req.status == 'PENDING'}">
                            <form method="post" action="${ctx}/TopupController" data-confirm="Confirm the money was received and add it to the user wallet?">
                                <input type="hidden" name="action" value="approve">
                                <input type="hidden" name="status" value="<c:out value="${status}"/>">
                                <input type="hidden" name="id" value="${req.requestId}">
                                <button type="submit" class="btn--sm btn--ok">Approve</button>
                            </form>
                            <form method="post" action="${ctx}/TopupController" data-confirm="Reject this top-up request?" data-confirm-danger>
                                <input type="hidden" name="action" value="reject">
                                <input type="hidden" name="status" value="<c:out value="${status}"/>">
                                <input type="hidden" name="id" value="${req.requestId}">
                                <button type="submit" class="link danger">Reject</button>
                            </form>
                        </c:if>
                        <c:if test="${req.status == 'APPROVED'}">
                            <span class="muted">Approved by <c:out value="${req.approvedByName}"/></span>
                        </c:if>
                    </td>
                </tr>
            </c:forEach>
            <c:if test="${empty allRequests}"><tr><td colspan="7" class="empty">No top-up requests.</td></tr></c:if>
        </table>
    </div>
</c:if>

<c:if test="${not (isStaff and not empty param.status)}">
    <div class="page-head">
        <div>
            <h2 id="pageTitle">Top up your wallet</h2>
            <p class="sub">Scan the VietQR code to make a bank transfer. Your balance is credited after the staff confirm it.</p>
        </div>
        <c:if test="${isStaff}"><a class="btn ghost" href="${ctx}/TopupController?status=PENDING">Top-up review</a></c:if>
    </div>

    <div class="grid-2">
        <section class="panel">
            <h3>New top-up request</h3>
            <form method="post" action="${ctx}/TopupController" id="topupForm">
                <input type="hidden" name="action" value="create">

                <p class="muted" style="margin:0 0 8px" id="presetLabel">Quick amounts</p>
                <div class="presets" role="group" aria-labelledby="presetLabel">
                    <button type="button" class="btn ghost" data-amt="20000" aria-pressed="false">20,000 VND</button>
                    <button type="button" class="btn ghost" data-amt="50000" aria-pressed="true">50,000 VND</button>
                    <button type="button" class="btn ghost" data-amt="100000" aria-pressed="false">100,000 VND</button>
                    <button type="button" class="btn ghost" data-amt="200000" aria-pressed="false">200,000 VND</button>
                </div>

                <div class="field" style="margin-top:14px">
                    <label for="amount">Or enter an amount (VND)</label>
                    <input type="number" id="amount" name="amount" value="50000" min="1000" step="1" required inputmode="numeric">
                </div>
                <p class="hint" style="margin-top:6px">Minimum 1,000 VND. Any amount works, e.g. 78888.</p>

                <div class="actions">
                    <button type="submit" class="btn--block">Create VietQR code</button>
                </div>
            </form>
        </section>

        <section class="panel">
            <c:choose>
                <c:when test="${not empty currentQr}">
                    <h3>Scan to pay</h3>
                    <img class="qr-img" src="<c:out value='${currentQr.qrUrl}'/>" alt="VietQR transfer code" width="280" height="280">
                    <dl class="kv">
                        <dt>Bank</dt><dd><c:out value="${bankName}"/></dd>
                        <dt>Account number</dt><dd><code><c:out value="${accountNumber}"/></code></dd>
                        <dt>Account holder</dt><dd><c:out value="${accountName}"/></dd>
                        <dt>Amount</dt><dd class="money"><fmt:formatNumber value="${currentQr.amount}" groupingUsed="true"/> VND</dd>
                        <dt>Transfer note (required)</dt><dd><code class="transfer-code"><c:out value="${currentQr.transferCode}"/></code></dd>
                        <dt>Status</dt>
                        <dd>
                            <ui:status value="${currentQr.status}"/>
                            <c:if test="${currentQr.status == 'REJECTED' and not empty currentQr.note}"><span class="muted"><c:out value="${currentQr.note}"/></span></c:if>
                        </dd>
                    </dl>
                </c:when>
                <c:otherwise>
                    <div class="qr-empty">
                        <div>
                            <p class="qr-empty-title">No QR code yet</p>
                            <p class="qr-empty-text">Choose an amount, then press <b>Create VietQR code</b> to get the transfer details.</p>
                        </div>
                    </div>
                </c:otherwise>
            </c:choose>
        </section>
    </div>

    <h3>Top-up history</h3>
    <div class="tablewrap">
        <table class="grid">
            <tr><th>#</th><th class="r">Amount</th><th>Transfer note</th><th>Created</th><th>Status</th><th>QR code</th></tr>
            <c:forEach var="req" items="${myRequests}">
                <tr>
                    <td class="num">${req.requestId}</td>
                    <td class="r"><span class="money"><fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> VND</span></td>
                    <td><code><c:out value="${req.transferCode}"/></code></td>
                    <td><ui:dt value="${req.createdAt}"/></td>
                    <td><ui:status value="${req.status}"/></td>
                    <td class="ops"><a href="${ctx}/TopupController?id=${req.requestId}">View QR code</a></td>
                </tr>
            </c:forEach>
            <c:if test="${empty myRequests}"><tr><td colspan="6" class="empty">You have no top-up requests yet.</td></tr></c:if>
        </table>
    </div>
</c:if>
<c:if test="${panel}">
</div>
</c:if>
<c:if test="${not panel}">
</main>

<script src="${ctx}/js/app.js"></script>
<script src="${ctx}/js/user-pages.js"></script>
</body>
</html>
</c:if>
