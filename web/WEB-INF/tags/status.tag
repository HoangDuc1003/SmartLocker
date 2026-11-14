<%-- Status tag: <ui:status value="${x.status}"/> prints the English label in a colored pill.
     kind="deposit" reads ACTIVE as "In use" instead of "Active". The raw code stays in the title. --%>
<%@ tag pageEncoding="UTF-8" body-content="empty" %>
<%@ attribute name="value" required="true" type="java.lang.Object" %>
<%@ attribute name="kind" required="false" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="v" value="${empty value ? '' : value.toString()}"/>
<c:choose>
    <c:when test="${v == 'ACTIVE' and kind == 'deposit'}"><c:set var="cls" value="info"/><c:set var="txt" value="In use"/></c:when>
    <c:when test="${v == 'ACTIVE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Active"/></c:when>
    <c:when test="${v == 'AVAILABLE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Available"/></c:when>
    <c:when test="${v == 'RESERVED'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Reserved"/></c:when>
    <c:when test="${v == 'OCCUPIED'}"><c:set var="cls" value="info"/><c:set var="txt" value="Occupied"/></c:when>
    <c:when test="${v == 'MAINTENANCE'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Maintenance"/></c:when>
    <c:when test="${v == 'OFFLINE'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Offline"/></c:when>
    <c:when test="${v == 'DISABLED'}"><c:set var="cls" value=""/><c:set var="txt" value="Disabled"/></c:when>
    <c:when test="${v == 'INACTIVE'}"><c:set var="cls" value=""/><c:set var="txt" value="Inactive"/></c:when>
    <c:when test="${v == 'LOCKED'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Locked"/></c:when>
    <c:when test="${v == 'BLOCKED'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Blocked"/></c:when>
    <c:when test="${v == 'LOST'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Reported lost"/></c:when>
    <c:when test="${v == 'OPEN'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Open"/></c:when>
    <c:when test="${v == 'RESOLVED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Resolved"/></c:when>
    <c:when test="${v == 'CLOSED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Closed"/></c:when>
    <c:when test="${v == 'COMPLETED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Completed"/></c:when>
    <c:when test="${v == 'NO_SHOW'}"><c:set var="cls" value=""/><c:set var="txt" value="No-show"/></c:when>
    <c:when test="${v == 'CANCELLED'}"><c:set var="cls" value=""/><c:set var="txt" value="Cancelled"/></c:when>
    <c:when test="${v == 'OVERDUE'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Overdue"/></c:when>
    <c:when test="${v == 'AWAITING_EMAIL'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Awaiting e-mail"/></c:when>
    <c:when test="${v == 'PENDING'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Pending"/></c:when>
    <c:when test="${v == 'SENT'}"><c:set var="cls" value="info"/><c:set var="txt" value="Sent"/></c:when>
    <c:when test="${v == 'DONE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Done"/></c:when>
    <c:when test="${v == 'EXPIRED'}"><c:set var="cls" value=""/><c:set var="txt" value="Expired"/></c:when>
    <c:when test="${v == 'APPROVED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Approved"/></c:when>
    <c:when test="${v == 'REJECTED'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Rejected"/></c:when>
    <c:when test="${v == 'ONLINE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Online"/></c:when>
    <c:when test="${v == 'DEGRADED'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Unstable"/></c:when>
    <c:otherwise><c:set var="cls" value=""/><c:set var="txt" value="${v}"/></c:otherwise>
</c:choose>
<span class="tag ${cls}" title="<c:out value='${v}'/>"><c:out value="${txt}"/></span>
