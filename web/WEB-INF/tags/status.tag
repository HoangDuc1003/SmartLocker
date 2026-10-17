<%-- Status tag: <ui:status value="${x.status}"/> prints the Vietnamese label in a colored pill.
     kind="deposit" reads ACTIVE as "Đang gửi" instead of "Hoạt động". The raw code stays in the title. --%>
<%@ tag pageEncoding="UTF-8" body-content="empty" %>
<%@ attribute name="value" required="true" type="java.lang.Object" %>
<%@ attribute name="kind" required="false" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<c:set var="v" value="${empty value ? '' : value.toString()}"/>
<c:choose>
    <c:when test="${v == 'ACTIVE' and kind == 'deposit'}"><c:set var="cls" value="info"/><c:set var="txt" value="Đang gửi"/></c:when>
    <c:when test="${v == 'ACTIVE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Hoạt động"/></c:when>
    <c:when test="${v == 'AVAILABLE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Trống"/></c:when>
    <c:when test="${v == 'RESERVED'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Đã đặt"/></c:when>
    <c:when test="${v == 'OCCUPIED'}"><c:set var="cls" value="info"/><c:set var="txt" value="Đang dùng"/></c:when>
    <c:when test="${v == 'MAINTENANCE'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Bảo trì"/></c:when>
    <c:when test="${v == 'OFFLINE'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Mất kết nối"/></c:when>
    <c:when test="${v == 'DISABLED'}"><c:set var="cls" value=""/><c:set var="txt" value="Vô hiệu"/></c:when>
    <c:when test="${v == 'INACTIVE'}"><c:set var="cls" value=""/><c:set var="txt" value="Ngừng hoạt động"/></c:when>
    <c:when test="${v == 'LOCKED'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Đã khóa"/></c:when>
    <c:when test="${v == 'BLOCKED'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Đã chặn"/></c:when>
    <c:when test="${v == 'LOST'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Báo mất"/></c:when>
    <c:when test="${v == 'OPEN'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Chưa xử lý"/></c:when>
    <c:when test="${v == 'RESOLVED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Đã xử lý"/></c:when>
    <c:when test="${v == 'CLOSED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Đã đóng"/></c:when>
    <c:when test="${v == 'COMPLETED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Hoàn tất"/></c:when>
    <c:when test="${v == 'NO_SHOW'}"><c:set var="cls" value=""/><c:set var="txt" value="Không đến"/></c:when>
    <c:when test="${v == 'CANCELLED'}"><c:set var="cls" value=""/><c:set var="txt" value="Đã hủy"/></c:when>
    <c:when test="${v == 'OVERDUE'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Quá hạn"/></c:when>
    <c:when test="${v == 'PENDING'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Chờ xử lý"/></c:when>
    <c:when test="${v == 'SENT'}"><c:set var="cls" value="info"/><c:set var="txt" value="Đã gửi"/></c:when>
    <c:when test="${v == 'DONE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Hoàn tất"/></c:when>
    <c:when test="${v == 'EXPIRED'}"><c:set var="cls" value=""/><c:set var="txt" value="Hết hạn"/></c:when>
    <c:when test="${v == 'APPROVED'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Đã duyệt"/></c:when>
    <c:when test="${v == 'REJECTED'}"><c:set var="cls" value="bad"/><c:set var="txt" value="Từ chối"/></c:when>
    <c:when test="${v == 'ONLINE'}"><c:set var="cls" value="ok"/><c:set var="txt" value="Trực tuyến"/></c:when>
    <c:when test="${v == 'DEGRADED'}"><c:set var="cls" value="warn"/><c:set var="txt" value="Chập chờn"/></c:when>
    <c:otherwise><c:set var="cls" value=""/><c:set var="txt" value="${v}"/></c:otherwise>
</c:choose>
<span class="tag ${cls}" title="<c:out value='${v}'/>"><c:out value="${txt}"/></span>
