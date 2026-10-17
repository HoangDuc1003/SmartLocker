<%-- Date and time: <ui:dt value="${x.createdAt}"/> prints 16/10/2026 21:55. date="true" prints the date only.
     A value that is not a java.util.Date is printed as text, empty prints a dash.
     The database stores SYSUTCDATETIME(), and JDBC reads that UTC wall clock in the JVM zone,
     so a timestamp is moved back to the real instant and printed in Vietnam time. --%>
<%@ tag pageEncoding="UTF-8" body-content="empty" trimDirectiveWhitespaces="true" %>
<%@ attribute name="value" required="true" type="java.lang.Object" %>
<%@ attribute name="date" required="false" type="java.lang.Boolean" %>
<%-- input="true" prints plain 2026-10-20 18:00:00 (Vietnam time) for the value of a text box --%>
<%@ attribute name="input" required="false" type="java.lang.Boolean" %>
<%
    Object v = jspContext.getAttribute("value");
    Boolean dateOnly = (Boolean) jspContext.getAttribute("date");
    boolean forInput = Boolean.TRUE.equals(jspContext.getAttribute("input"));
    String text;
    if (v == null || "".equals(v)) {
        text = forInput ? "" : "–";
    } else if (v instanceof java.util.Date) {
        String pattern = forInput ? "yyyy-MM-dd HH:mm:ss"
                : (dateOnly != null && dateOnly) || v instanceof java.sql.Date ? "dd/MM/yyyy" : "dd/MM/yyyy HH:mm";
        java.text.SimpleDateFormat f = new java.text.SimpleDateFormat(pattern);
        long ms = ((java.util.Date) v).getTime();
        if (!(v instanceof java.sql.Date)) {
            ms += java.util.TimeZone.getDefault().getOffset(ms);
            f.setTimeZone(java.util.TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
        }
        text = f.format(new java.util.Date(ms));
    } else {
        text = v.toString();
    }
    String safe = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    out.write(forInput ? safe : "<span class=\"num\">" + safe + "</span>");
%>
