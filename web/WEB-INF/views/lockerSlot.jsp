<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="slots"/>
<%-- The model of every CRUD page. One JSP, two modes: LockerSlotController sets mode = list or form.
     Attributes of the list: items, total, page, pages, q, bankId, status, banks.
     Attributes of the form: item, isNew, banks, and error after a failed save. --%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Slots · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Add slot' : 'Edit slot'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <%-- the browser checks save a round trip, the controller repeats every rule --%>
    <form class="form" method="post" action="${ctx}/LockerSlotController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.slotId}">

        <label for="bankId">Locker bank <span class="req">*</span></label>
        <select id="bankId" name="bankId" required>
            <option value="">Choose a locker bank</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${item.bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>

        <label for="slotCode">Slot code <span class="req">*</span></label>
        <input type="text" id="slotCode" name="slotCode" value="<c:out value='${item.slotCode}'/>"
               required maxlength="20" pattern="[A-Za-z0-9_-]{1,20}" title="1 to 20 letters, digits, - or _" placeholder="A01">

        <label for="sizeCode">Size <span class="req">*</span></label>
        <select id="sizeCode" name="sizeCode" required>
            <option value="S" ${item.sizeCode == 'S' ? 'selected' : ''}>S – small</option>
            <option value="M" ${item.sizeCode == 'M' ? 'selected' : ''}>M – medium</option>
            <option value="L" ${item.sizeCode == 'L' ? 'selected' : ''}>L – large (twice as tall on the map)</option>
        </select>

        <label for="sizeCm">Dimensions (cm)</label>
        <input type="text" id="sizeCm" name="sizeCm" value="<c:out value='${item.sizeCm}'/>" maxlength="20" placeholder="30x30x45">

        <label for="status">Status <span class="req">*</span></label>
        <select id="status" name="status" required>
            <option value="AVAILABLE" ${item.status == 'AVAILABLE' ? 'selected' : ''}>Available</option>
            <option value="RESERVED" ${item.status == 'RESERVED' ? 'selected' : ''}>Reserved</option>
            <option value="OCCUPIED" ${item.status == 'OCCUPIED' ? 'selected' : ''}>Occupied</option>
            <option value="MAINTENANCE" ${item.status == 'MAINTENANCE' ? 'selected' : ''}>Maintenance</option>
        </select>

        <div class="actions">
            <button type="submit">Save</button>
            <a class="btn ghost" href="${ctx}/LockerSlotController">Cancel</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Slots <span class="count">(${total})</span></h2>
        <%-- the controls of a role without WRITE are not drawn; the filter would refuse the request anyway --%>
        <c:if test="${perms.contains('LOCKERSLOT:WRITE')}"><a class="btn" href="${ctx}/LockerSlotController?action=new">Add slot</a></c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/LockerSlotController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Slot code" aria-label="Slot code">
        <select name="bankId" aria-label="Locker bank">
            <option value="">All locker banks</option>
            <c:forEach var="b" items="${banks}">
                <option value="${b.bankId}" ${bankId == b.bankId ? 'selected' : ''}><c:out value="${b.bankCode}"/></option>
            </c:forEach>
        </select>
        <select name="status" aria-label="Status">
            <option value="">All statuses</option>
            <option value="AVAILABLE" ${status == 'AVAILABLE' ? 'selected' : ''}>Available</option>
            <option value="RESERVED" ${status == 'RESERVED' ? 'selected' : ''}>Reserved</option>
            <option value="OCCUPIED" ${status == 'OCCUPIED' ? 'selected' : ''}>Occupied</option>
            <option value="MAINTENANCE" ${status == 'MAINTENANCE' ? 'selected' : ''}>Maintenance</option>
        </select>
        <button type="submit">Filter</button>
        <a class="btn ghost" href="${ctx}/LockerSlotController">Clear filters</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/LockerSlotController">
            <c:param name="action" value="export"/><c:param name="q" value="${q}"/>
            <c:param name="bankId" value="${bankId}"/><c:param name="status" value="${status}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Export CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Locker bank</th><th>Slot</th><th>Size</th><th>Dimensions (cm)</th><th>Status</th><th>Actions</th></tr>
        <c:forEach var="s" items="${items}">
        <tr class="${s.status == 'MAINTENANCE' ? 'locked' : ''}">
            <td class="num">${s.slotId}</td>
            <td><c:out value="${s.bankCode}"/></td>
            <td><b><c:out value="${s.slotCode}"/></b></td>
            <td><c:out value="${s.sizeCode}"/></td>
            <td><c:out value="${s.sizeCm}"/></td>
            <td><ui:status value="${s.status}"/></td>
            <td class="ops">
                <c:if test="${perms.contains('SLOTSTATUS:WRITE')}">
                    <form method="post" action="${ctx}/LockerSlotController" data-confirm-danger
                          data-confirm="Change the status of slot <c:out value="${s.slotCode}"/>? The change is written to the audit log.">
                        <input type="hidden" name="action" value="status">
                        <input type="hidden" name="id" value="${s.slotId}">
                        <select name="status" aria-label="New status of slot <c:out value="${s.slotCode}"/>" required>
                            <option value="AVAILABLE" ${s.status == 'AVAILABLE' ? 'selected' : ''}>Available</option>
                            <option value="RESERVED" ${s.status == 'RESERVED' ? 'selected' : ''}>Reserved</option>
                            <option value="OCCUPIED" ${s.status == 'OCCUPIED' ? 'selected' : ''}>Occupied</option>
                            <option value="MAINTENANCE" ${s.status == 'MAINTENANCE' ? 'selected' : ''}>Maintenance</option>
                        </select>
                        <button type="submit" class="btn--sm ghost">Update</button>
                    </form>
                </c:if>
                <c:if test="${perms.contains('LOCKERSLOT:WRITE')}">
                    <a href="${ctx}/LockerSlotController?action=edit&amp;id=${s.slotId}">Edit</a>
                    <%-- never print data inside inline JavaScript: a quote in the data would break out of the string --%>
                    <form method="post" action="${ctx}/LockerSlotController" data-confirm="Delete this slot?" data-confirm-danger>
                        <input type="hidden" name="action" value="delete">
                        <input type="hidden" name="id" value="${s.slotId}">
                        <button type="submit" class="link danger">Delete</button>
                    </form>
                </c:if>
            </td>
        </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="7" class="empty">No slots match the filters.</td></tr></c:if>
    </table>
    </div>

    <%-- c:url encodes every value, so a keyword with & or a space cannot break the link --%>
    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
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
</main>
<script src="${ctx}/js/app.js"></script>
</body>
</html>
