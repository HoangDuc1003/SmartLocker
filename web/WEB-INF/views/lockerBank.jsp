<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="ui" tagdir="/WEB-INF/tags" %>
<c:set var="activeNav" value="banks"/>
<%--
  Banks. Controller: LockerBankController
  Attributes it sets: list: items (LockerBank), total, page, pages, q, areaId, areas. form: item, isNew, areas, devices, error
  A bank without a device is drawn for illustration only on the map.
--%>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Dãy tủ · Smart Locker</title>
    <script src="${pageContext.request.contextPath}/js/theme.js"></script>
    <link rel="stylesheet" href="${pageContext.request.contextPath}/css/app.css">
</head>
<body>
<%@ include file="common/nav.jspf" %>
<main id="main" class="wrap">
<c:choose>

<%-- ================= FORM ================= --%>
<c:when test="${mode == 'form'}">
    <h2>${isNew ? 'Thêm dãy tủ' : 'Sửa dãy tủ'}</h2>
    <c:if test="${not empty error}"><div class="error" role="alert"><c:out value="${error}"/></div></c:if>

    <form class="form" method="post" action="${ctx}/LockerBankController">
        <input type="hidden" name="action" value="${isNew ? 'create' : 'update'}">
        <input type="hidden" name="id" value="${item.bankId}">

        <label for="bankCode">Mã dãy tủ <span class="req">*</span></label>
        <input type="text" id="bankCode" name="bankCode" value="<c:out value='${item.bankCode}'/>"
               required minlength="2" maxlength="20" pattern="[A-Za-z0-9_-]{2,20}"
               title="2 đến 20 chữ cái, số, - hoặc _" ${!isNew ? 'readonly' : ''}>

        <label for="name">Tên dãy tủ <span class="req">*</span></label>
        <input type="text" id="name" name="name" value="<c:out value='${item.name}'/>" required minlength="1" maxlength="40">

        <label for="areaId">Khu vực <span class="req">*</span></label>
        <select id="areaId" name="areaId" required>
            <option value="">Chọn khu vực</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${item.areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> – <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>

        <label for="deviceId">Bộ điều khiển (ESP32)</label>
        <select id="deviceId" name="deviceId" aria-describedby="deviceHint">
            <option value="">Không có (chỉ minh họa)</option>
            <c:forEach var="d" items="${devices}">
                <option value="${d.deviceId}" ${item.deviceId == d.deviceId ? 'selected' : ''}><c:out value="${d.deviceCode}"/> (<c:out value="${d.location}"/>)</option>
            </c:forEach>
        </select>
        <p class="hint" id="deviceHint">Dãy tủ không có bộ điều khiển chỉ được vẽ trên sơ đồ, không mở khóa được.
            Hộp thật, các dãy nó quản lý và ngăn có khóa thật được đặt bằng <code>sql/demo_box.sql</code>.</p>

        <label for="doorRows">Số hàng cửa (1–8) <span class="req">*</span></label>
        <input type="number" id="doorRows" name="doorRows" value="${item.doorRows > 0 ? item.doorRows : 4}" required min="1" max="8">

        <label for="status">Trạng thái <span class="req">*</span></label>
        <select id="status" name="status" required>
            <option value="ACTIVE" ${item.status == 'ACTIVE' ? 'selected' : ''}>Hoạt động</option>
            <option value="MAINTENANCE" ${item.status == 'MAINTENANCE' ? 'selected' : ''}>Bảo trì</option>
        </select>

        <div class="actions">
            <button type="submit">Lưu</button>
            <a class="btn ghost" href="${ctx}/LockerBankController">Hủy</a>
        </div>
    </form>
</c:when>

<%-- ================= LIST ================= --%>
<c:otherwise>
    <div class="page-head">
        <h2>Dãy tủ <span class="count">(${total})</span></h2>
        <c:if test="${perms.contains('LOCKERBANK:WRITE')}">
            <a class="btn" href="${ctx}/LockerBankController?action=new">Thêm dãy tủ</a>
        </c:if>
    </div>

    <form class="filter" method="get" action="${ctx}/LockerBankController">
        <input type="text" name="q" value="<c:out value='${q}'/>" placeholder="Mã hoặc tên dãy tủ" aria-label="Tìm kiếm">
        <select name="areaId" aria-label="Khu vực">
            <option value="">Tất cả khu vực</option>
            <c:forEach var="a" items="${areas}">
                <option value="${a.areaId}" ${areaId == a.areaId ? 'selected' : ''}><c:out value="${a.areaCode}"/> – <c:out value="${a.name}"/></option>
            </c:forEach>
        </select>
        <button type="submit">Lọc</button>
        <a class="btn ghost" href="${ctx}/LockerBankController">Xóa lọc</a>
        <span class="spacer"></span>
        <c:url var="exportUrl" value="/LockerBankController">
            <c:param name="action" value="export"/>
            <c:param name="q" value="${q}"/>
            <c:param name="areaId" value="${areaId}"/>
        </c:url>
        <a class="btn ghost" href="${exportUrl}">Xuất CSV</a>
    </form>

    <div class="tablewrap">
    <table class="grid">
        <tr><th>#</th><th>Mã</th><th>Tên</th><th>Khu vực</th><th>Bộ điều khiển</th><th class="r">Số hàng</th><th class="r">Số ngăn</th><th>Trạng thái</th><th>Thao tác</th></tr>
        <c:forEach var="x" items="${items}">
            <tr class="${x.status == 'MAINTENANCE' ? 'locked' : ''}">
                <td class="num">${x.bankId}</td>
                <td><b><c:out value="${x.bankCode}"/></b></td>
                <td><c:out value="${x.name}"/></td>
                <td><c:out value="${x.areaCode}"/></td>
                <td>
                    <c:choose>
                        <c:when test="${x.deviceId != null && x.demoDevice}">
                            <c:out value="${x.deviceCode}"/> <span class="tag">Mô phỏng</span>
                        </c:when>
                        <c:when test="${x.deviceId != null}">
                            <c:out value="${x.deviceCode}"/> <span class="tag info">Hộp thật</span>
                            <div class="hint">
                                <c:choose>
                                    <c:when test="${empty x.physicalSlot}">Mọi ngăn mở khóa thật</c:when>
                                    <c:when test="${x.physicalBank == x.bankCode}">Ngăn có khóa thật: <b><c:out value="${x.physicalSlot}"/></b>, ngăn khác chỉ báo OK</c:when>
                                    <c:otherwise>Ngăn có khóa thật ở dãy <c:out value="${x.physicalBank}"/> (<c:out value="${x.physicalSlot}"/>), ngăn ở đây chỉ báo OK</c:otherwise>
                                </c:choose>
                            </div>
                        </c:when>
                        <c:otherwise><span class="tag">Chỉ minh họa</span></c:otherwise>
                    </c:choose>
                </td>
                <td class="r num">${x.doorRows}</td>
                <td class="r num">${x.slotCount}</td>
                <td><ui:status value="${x.status}"/></td>
                <td class="ops">
                    <c:if test="${perms.contains('LOCKERBANK:WRITE')}">
                        <a href="${ctx}/LockerBankController?action=edit&amp;id=${x.bankId}">Sửa</a>
                        <form method="post" action="${ctx}/LockerBankController" data-confirm="Xóa dãy tủ này?" data-confirm-danger>
                            <input type="hidden" name="action" value="delete">
                            <input type="hidden" name="id" value="${x.bankId}">
                            <button type="submit" class="link danger">Xóa</button>
                        </form>
                    </c:if>
                </td>
            </tr>
        </c:forEach>
        <c:if test="${empty items}"><tr><td colspan="9" class="empty">Không có dãy tủ nào khớp bộ lọc.</td></tr></c:if>
    </table>
    </div>

    <div class="pager">
        <c:forEach var="p" begin="1" end="${pages}">
            <c:choose>
                <c:when test="${p == page}"><b aria-current="page">${p}</b></c:when>
                <c:otherwise>
                    <c:url var="pageUrl" value="/LockerBankController">
                        <c:param name="q" value="${q}"/>
                        <c:param name="areaId" value="${areaId}"/>
                        <c:param name="page" value="${p}"/>
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
