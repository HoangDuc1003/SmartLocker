<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<c:set var="activeNav" value="topup"/>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Add funds - Smart Locker</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
    <style>
        .topup-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-top: 16px; }
        @media (max-width: 800px) { .topup-grid { grid-template-columns: 1fr; } }
        .qr-card { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .qr-img { max-width: 300px; width: 100%; border-radius: 8px; border: 1px solid #ddd; margin: 12px 0; }
        .bank-info { text-align: left; background: #f9f9f9; padding: 12px 16px; border-radius: 6px; font-size: 14px; margin-top: 12px; }
        .bank-info dt { font-weight: bold; color: #555; }
        .bank-info dd { margin-bottom: 8px; color: #222; }
        .preset-amounts { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
        .preset-btn { background: #f0f4f8; border: 1px solid #c5d5e5; padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 13px; font-weight: 500; }
        .preset-btn:hover { background: #e1ebf5; }
        .status-badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; }
        .status-pending { background: #fff3e0; color: #e65100; border: 1px solid #ffe0b2; }
        .status-approved { background: #e8f5e9; color: #2e7d32; border: 1px solid #c8e6c9; }
        .status-rejected { background: #ffebee; color: #c62828; border: 1px solid #ffcdd2; }
    </style>
</head>
<body>
<%@ include file="common/nav.jspf" %>

<div class="wrap">
    <h2>Add funds to your account</h2>
    <p class="sub">Scan the VietQR code to transfer funds. Your account balance updates after staff confirms the payment.</p>

    <c:if test="${isStaff}">
        <%-- Staff review of account top-ups. --%>
        <div style="background: #eef6fc; border: 1px solid #bce; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
            <h3 style="margin-top: 0; color: #004b87;">Top-up requests</h3>
            <form class="filter" method="get" action="${ctx}/TopupController">
                <select name="status">
                    <option value="">All statuses</option>
                    <option value="PENDING" ${status == 'PENDING' ? 'selected' : ''}>Pending</option>
                    <option value="APPROVED" ${status == 'APPROVED' ? 'selected' : ''}>Approved</option>
                    <option value="REJECTED" ${status == 'REJECTED' ? 'selected' : ''}>Rejected</option>
                </select>
                <button type="submit">Filter</button>
                <a class="btn ghost" href="${ctx}/TopupController">Clear filter</a>
            </form>

            <div class="tablewrap" style="background:#fff; border-radius:6px;">
                <table class="grid">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>User</th>
                            <th class="r">Amount</th>
                            <th>Transfer code</th>
                            <th>Created</th>
                            <th class="c">Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <c:forEach var="req" items="${allRequests}">
                            <tr>
                                <td>${req.requestId}</td>
                                <td><b><c:out value="${req.username}"/></b> <span class="muted">(<c:out value="${req.fullName}"/>)</span></td>
                                <td class="r" style="font-weight:bold; color:#2e7d32;">
                                    <fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> VND
                                </td>
                                <td><code><c:out value="${req.transferCode}"/></code></td>
                                <td style="font-size: 12px;"><fmt:formatDate value="${req.createdAt}" pattern="yyyy-MM-dd HH:mm"/></td>
                                <td class="c">
                                    <c:choose>
                                        <c:when test="${req.status == 'PENDING'}">
                                            <span class="status-badge status-pending">Pending</span>
                                        </c:when>
                                        <c:when test="${req.status == 'APPROVED'}">
                                            <span class="status-badge status-approved">Approved</span>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="status-badge status-rejected">Rejected</span>
                                        </c:otherwise>
                                    </c:choose>
                                </td>
                                <td class="ops">
                                    <c:if test="${req.status == 'PENDING'}">
                                        <form method="post" action="${ctx}/TopupController" style="display:inline;" onsubmit="return confirm('Confirm payment and add funds to this account?');">
                                            <input type="hidden" name="action" value="approve">
                                            <input type="hidden" name="id" value="${req.requestId}">
                                            <button type="submit" class="btn" style="background:#2e7d32; color:#fff; padding:4px 8px; font-size:12px; border:none; cursor:pointer;">Approve and add funds</button>
                                        </form>
                                        <form method="post" action="${ctx}/TopupController" style="display:inline;" onsubmit="return confirm('Reject this top-up request?');">
                                            <input type="hidden" name="action" value="reject">
                                            <input type="hidden" name="id" value="${req.requestId}">
                                            <button type="submit" class="btn btn--danger" style="padding:4px 8px; font-size:12px;">Reject</button>
                                        </form>
                                    </c:if>
                                    <c:if test="${req.status == 'APPROVED'}">
                                        <span class="muted" style="font-size:11px;">Approved by <c:out value="${req.approvedByName}"/></span>
                                    </c:if>
                                </td>
                            </tr>
                        </c:forEach>
                        <c:if test="${empty allRequests}">
                            <tr><td colspan="7" class="c">No top-up requests.</td></tr>
                        </c:if>
                    </tbody>
                </table>
            </div>
        </div>
    </c:if>

    <%-- Account top-up form and VietQR payment details. --%>
    <div class="topup-grid">
        <div class="box" style="background:#fff; border:1px solid #e0e0e0; border-radius:8px; padding:20px;">
            <h3 style="margin-top:0;">Create a top-up request</h3>
            <form method="post" action="${ctx}/TopupController" id="topupForm">
                <input type="hidden" name="action" value="create">

                <label><b>Choose an amount:</b></label>
                <div class="preset-amounts">
                    <button type="button" class="preset-btn" onclick="setAmount(20000)">20,000 VND</button>
                    <button type="button" class="preset-btn" onclick="setAmount(50000)">50,000 VND</button>
                    <button type="button" class="preset-btn" onclick="setAmount(100000)">100,000 VND</button>
                    <button type="button" class="preset-btn" onclick="setAmount(200000)">200,000 VND</button>
                </div>

                <label for="amount"><b>Or enter an amount (VND):</b></label>
                <input type="number" id="amount" name="amount" value="50000" min="1000" step="1000" required style="width:100%; margin-bottom:16px; padding:8px; font-size:16px; font-weight:bold;">

                <button type="submit" class="btn btn--primary btn--block" style="font-size:15px; padding:10px;">
                    Generate VietQR code
                </button>
            </form>
        </div>

        <div>
            <c:choose>
                <c:when test="${not empty currentQr}">
                    <div class="qr-card">
                        <h3 style="margin-top:0; color:#004b87;">Scan to pay</h3>
                        <p style="font-size:13px; color:#666; margin-bottom:8px;">Open your banking app and scan this VietQR code:</p>

                        <img class="qr-img" src="${currentQr.qrUrl}" alt="VietQR payment code">

                        <div class="bank-info">
                            <dl style="margin:0;">
                                <dt>Bank:</dt>
                                <dd><c:out value="${bankName}"/></dd>
                                <dt>Account number:</dt>
                                <dd><code><c:out value="${accountNumber}"/></code></dd>
                                <dt>Account name:</dt>
                                <dd><c:out value="${accountName}"/></dd>
                                <dt>Amount:</dt>
                                <dd><strong style="color:#2e7d32; font-size:16px;"><fmt:formatNumber value="${currentQr.amount}" groupingUsed="true"/> VND</strong></dd>
                                <dt>Transfer note (required):</dt>
                                <dd><code style="background:#fff3e0; color:#d32f2f; font-weight:bold; font-size:14px; padding:2px 6px; border-radius:4px;"><c:out value="${currentQr.transferCode}"/></code></dd>
                                <dt>Request status:</dt>
                                <dd>
                                    <c:choose>
                                        <c:when test="${currentQr.status == 'PENDING'}">
                                            <span class="status-badge status-pending">Waiting for staff confirmation</span>
                                        </c:when>
                                        <c:when test="${currentQr.status == 'APPROVED'}">
                                            <span class="status-badge status-approved">Funds added to your account</span>
                                        </c:when>
                                        <c:otherwise>
                                            <span class="status-badge status-rejected">Rejected: <c:out value="${currentQr.note}"/></span>
                                        </c:otherwise>
                                    </c:choose>
                                </dd>
                            </dl>
                        </div>
                    </div>
                </c:when>
                <c:otherwise>
                    <div class="qr-card" style="padding:40px 20px; color:#888;">
                        <p style="font-size:16px;">Choose an amount and select <b>Generate VietQR code</b> to see payment details.</p>
                    </div>
                </c:otherwise>
            </c:choose>
        </div>
    </div>

    <%-- The user's top-up history. --%>
    <h3 style="margin-top:32px;">Your top-up history</h3>
    <div class="tablewrap" style="background:#fff; border-radius:6px;">
        <table class="grid">
            <thead>
                <tr>
                    <th>#</th>
                    <th class="r">Amount</th>
                    <th>Transfer code</th>
                    <th>Created</th>
                    <th class="c">Status</th>
                    <th>QR code</th>
                </tr>
            </thead>
            <tbody>
                <c:forEach var="req" items="${myRequests}">
                    <tr>
                        <td>${req.requestId}</td>
                        <td class="r" style="font-weight:bold; color:#2e7d32;">
                            <fmt:formatNumber value="${req.amount}" type="number" groupingUsed="true"/> VND
                        </td>
                        <td><code><c:out value="${req.transferCode}"/></code></td>
                        <td><fmt:formatDate value="${req.createdAt}" pattern="yyyy-MM-dd HH:mm"/></td>
                        <td class="c">
                            <c:choose>
                                <c:when test="${req.status == 'PENDING'}">
                                    <span class="status-badge status-pending">Pending</span>
                                </c:when>
                                <c:when test="${req.status == 'APPROVED'}">
                                    <span class="status-badge status-approved">Approved</span>
                                </c:when>
                                <c:otherwise>
                                    <span class="status-badge status-rejected">Rejected</span>
                                </c:otherwise>
                            </c:choose>
                        </td>
                        <td>
                            <a class="btn ghost btn--sm" href="${ctx}/TopupController?id=${req.requestId}" style="padding:2px 8px; font-size:12px;">View QR</a>
                        </td>
                    </tr>
                </c:forEach>
                <c:if test="${empty myRequests}">
                    <tr><td colspan="6" class="c">You have no top-up requests.</td></tr>
                </c:if>
            </tbody>
        </table>
    </div>
</div>

<script>
function setAmount(val) {
    document.getElementById('amount').value = val;
}
</script>
</body>
</html>
