<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="activeNav" value="slots"/>
<%-- The model of every CRUD page. One JSP, two modes: LockerSlotController sets mode = list or form.
     Attributes of the list: items, total, page, pages, q, bankId, status, banks.
     Attributes of the form: item, isNew, banks, and error after a failed save. --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#2b3a55">
    <title>Slots</title>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<div class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add a slot' : 'Edit slot'}</h2>
    <c:if test="${not empty error}"><div class="error"><c:out value="${error}"/></div></c:if>

    <%-- the browser checks save a round trip, the controller repeats every rule --%>
    <form class="form" method="post" action="${ctx}/LockerSlotController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.slotId}">

        <label for="bankId">Bank *</label>
        <select id="bankId" name="bankId" required>
            <option value="">-- Choose a bank --</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${item.bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>

        <label for="slotCode">Slot code *</label>
        <input type="text" id="slotCode" name="slotCode" value="<c:out value='${item.slotCode}'/>"
               required maxlength="20" pattern="[A-Za-z0-9_-]{1,20}" title="1 to 20 letters, digits, - or _">

        <label for="sizeCode">Size *</label>
        <select id="sizeCode" name="sizeCode" required>
            <option value="S" ${item.sizeCode == 'S' ? 'selected' : ''}>S, small</option>
            <option value="M" ${item.sizeCode == 'M' ? 'selected' : ''}>M, medium</option>
            <option value="L" ${item.sizeCode == 'L' ? 'selected' : ''}>L, large (two rows high on the map)</option>
        </select>

        <label for="sizeCm">Size in cm</label>
        <input type="text" id="sizeCm" name="sizeCm" value="<c:out value='${item.sizeCm}'/>" maxlength="20" placeholder="30x30x45">

        <label for="status">Status *</label>
        <select id="status" name="status" required>
            <c:forEach var="st" items="AVAILABLE,RESERVED,OCCUPIED,MAINTENANCE">
                <option value="${st}" ${item.status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerSlotController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <h2>Slots (${total})</h2>

    <form class="filter" method="get" action="${ctx}/LockerSlotController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Slot code">
        <select name="bankId">
            <option value="">-- All banks --</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>
        <select name="status">
            <option value="">-- All statuses --</option>
            <c:forEach var="st" items="AVAILABLE,RESERVED,OCCUPIED,MAINTENANCE">
                <option value="${st}" ${status == st ? 'selected' : ''}>${st}</option>
            </c:forEach>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerSlotController">Clear</a>
        <%-- the controls of a role without WRITE are not drawn; the filter would refuse the request anyway --%>
        <c:if test="${perms.contains('LOCKERSLOT:WRITE')}"><a class="btn" href="${ctx}/LockerSlotController?action=new">Add slot</a></c:if>
        <c:url var="exportUrl" value="/LockerSlotController">
            <c:param name="action" value="export"/><c:param name="q" value="${q}"/>
            <c:param name="bankId" value="${bankId}"/><c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Bank</th><th>Slot</th><th>Size</th><th>Size (cm)</th><th class="c">Status</th><th>Actions</th></tr>
        <c:forEach var="s" items="${items}">
        <tr class="${s.status == 'MAINTENANCE' ? 'locked' : ''}">
            <td>${s.slotId}</td>
            <td><c:out value="${s.bankCode}"/></td>
            <td><c:out value="${s.slotCode}"/></td>
            <td>${s.sizeCode}</td>
            <td><c:out value="${s.sizeCm}"/></td>
            <td class="c">${s.status}</td>
            <td class="ops">
                <c:if test="${perms.contains('LOCKERSLOT:WRITE')}">
                    <a href="${ctx}/LockerSlotController?action=edit&amp;id=${s.slotId}">Edit</a>
                    <%-- never print data inside inline JavaScript: a quote in the data would break out of the string --%>
                    <form method="post" action="${ctx}/LockerSlotController" onsubmit="return confirm('Delete this slot?');">
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${s.slotId}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="c">No slot matches the filter</td></tr></c:if>
    </table>
    </div>

    <%-- c:url encodes every value, so a keyword with & or a space cannot break the link --%>
    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b>${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/LockerSlotController">
                        <c:param name="q" value="${q}"/><c:param name="bankId" value="${bankId}"/>
                        <c:param name="status" value="${status}"/><c:param name="page" value="${p}"/>
                    </c:url>
                    <a href="${pageUrl}">${p}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>
    </div>
</c:otherwise>

</c:choose>
</div>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
