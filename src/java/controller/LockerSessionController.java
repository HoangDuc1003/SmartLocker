package controller;

import dao.LockerSessionDao;
import java.io.IOException;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Web;

/**
 * "Dữ liệu cảm biến": every open/close session a box posted to /api/locker/batch (LockerSessionApi), the IoT input of
 * the project, newest first. GET only (the table is append-only): search by a word, filter by box and by a range of
 * measured dates (Vietnam time), sort by a column, 20 rows a page. A record sent during the demo shows up on reload.
 */
@WebServlet(name = "LockerSessionController", urlPatterns = {"/LockerSessionController"})
public class LockerSessionController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/lockerSession.jsp";
    private static final int PAGE_SIZE = 20;
    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final DateTimeFormatter UTC_TEXT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /** 00:00 of a Vietnam date as the UTC text the query compares with; null for an empty or bad date. */
    public static String startOfDayUtc(LocalDate day) {
        return day == null ? null : day.atStartOfDay(VN).withZoneSameInstant(ZoneOffset.UTC).format(UTC_TEXT);
    }

    /** DATETIME2 takes years 1 to 9999; the date picker allows far more, so the filter keeps to sensible years. */
    static final int MIN_YEAR = 2000;
    static final int MAX_YEAR = 2100;

    /** True for no date, or a date whose year is within MIN_YEAR..MAX_YEAR. */
    public static boolean inRange(LocalDate day) {
        return day == null || (day.getYear() >= MIN_YEAR && day.getYear() <= MAX_YEAR);
    }

    /** "2026-11-10" -> the date; null when empty; throws on a bad text. */
    public static LocalDate parseDate(String text) {
        return text == null || text.isEmpty() ? null : LocalDate.parse(text);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        LockerSessionDao.Filter f = new LockerSessionDao.Filter();
        String q = Web.trimmed(req, "q");
        if (q.length() > 50) {
            q = q.substring(0, 50);
        }
        f.q = q;
        f.deviceId = Web.optionalInt(req, "deviceId");
        String sort = Web.trimmed(req, "sort");
        f.sort = LockerSessionDao.SORTS.containsKey(sort) ? sort : "measured";
        f.desc = !"asc".equals(Web.trimmed(req, "dir"));
        String from = Web.trimmed(req, "from");
        String to = Web.trimmed(req, "to");
        String error = null;
        try {
            LocalDate fromDay = parseDate(from);
            LocalDate toDay = parseDate(to);
            if (!inRange(fromDay) || !inRange(toDay)) {
                error = "Năm phải nằm trong khoảng " + MIN_YEAR + " đến " + MAX_YEAR + ".";
            } else if (fromDay != null && toDay != null && fromDay.isAfter(toDay)) {
                error = "Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.";
            } else {
                f.fromUtc = startOfDayUtc(fromDay);
                f.toUtc = startOfDayUtc(toDay == null ? null : toDay.plusDays(1));   // the whole last day is included
            }
        } catch (DateTimeParseException e) {
            error = "Ngày phải có dạng năm-tháng-ngày, ví dụ 2026-11-10.";
        }
        try {
            // a bad filter lists nothing: the whole table under an error would look like a filtered result
            LockerSessionDao dao = new LockerSessionDao();
            int total = error == null ? dao.count(f) : 0;
            int pages = Web.pages(total, PAGE_SIZE);
            int page = Math.min(Math.max(1, Web.intParam(req, "page", 1)), pages);
            List<Map<String, Object>> items = error == null ? dao.list(f, page, PAGE_SIZE)
                    : java.util.Collections.<Map<String, Object>>emptyList();
            req.setAttribute("items", items);
            req.setAttribute("total", total);
            req.setAttribute("page", page);
            req.setAttribute("pages", pages);
            req.setAttribute("q", q);
            req.setAttribute("deviceId", f.deviceId);
            req.setAttribute("from", from);
            req.setAttribute("to", to);
            req.setAttribute("sort", f.sort);
            req.setAttribute("dir", f.desc ? "desc" : "asc");
            req.setAttribute("error", error);
            req.setAttribute("devices", new dao.DeviceDao().listAll());
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
