package filter;

import dao.DeviceDao;
import dao.PermissionDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.annotation.WebFilter;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.User;
import util.Web;

/**
 * One filter guards every path. It lets public pages through, lets a device in with its API key,
 * and for everything else checks the signed-in user holds the permission of the resource behind the path.
 * Hiding a link in a JSP is a convenience; this class is what really stops a request.
 */
@WebFilter(urlPatterns = {"/*"})
public class SecurityFilter implements Filter {

    /** Reachable without signing in. */
    private static final Set<String> PUBLIC_PATHS = new HashSet<>(Arrays.asList(
            "/", "/index.html", "/favicon.ico", "/LoginController", "/RegisterController", "/LogoutController"));
    private static final String[] PUBLIC_PREFIXES = {"/css/", "/js/", "/img/", "/demo/"};

    /** The device signs with an X-API-Key header instead of a login. */
    private static final Set<String> DEVICE_API_PATHS = new HashSet<>(Arrays.asList(
            "/api/health", "/api/locker/batch"));

    /** servlet path -> resource name in the Permissions table. GET needs READ, anything else needs WRITE. */
    private static final Map<String, String> RESOURCE_BY_PATH = new HashMap<>();

    static {
        RESOURCE_BY_PATH.put("/LockerMapController", "MAP");
        RESOURCE_BY_PATH.put("/api/locker-map", "MAP");
        RESOURCE_BY_PATH.put("/DashboardController", "ALERT");
        RESOURCE_BY_PATH.put("/api/dashboard", "ALERT");
        RESOURCE_BY_PATH.put("/AlertController", "ALERT");
        RESOURCE_BY_PATH.put("/MaintenanceController", "MAINTENANCE");
        RESOURCE_BY_PATH.put("/CalibrationController", "CALIBRATION");
        RESOURCE_BY_PATH.put("/LockerAreaController", "AREA");
        RESOURCE_BY_PATH.put("/LockerBankController", "LOCKERBANK");
        RESOURCE_BY_PATH.put("/LockerSlotController", "LOCKERSLOT");
        RESOURCE_BY_PATH.put("/StoragePlanController", "STORAGEPLAN");
        RESOURCE_BY_PATH.put("/UserCardController", "USERCARD");
        RESOURCE_BY_PATH.put("/DepositController", "DEPOSIT");
        RESOURCE_BY_PATH.put("/RemoteCommandController", "COMMAND");
        RESOURCE_BY_PATH.put("/BookingController", "BOOKING");
        RESOURCE_BY_PATH.put("/MyCardController", "MYCARD");
        RESOURCE_BY_PATH.put("/UserController", "USER");
        RESOURCE_BY_PATH.put("/RoleController", "ROLE");
        RESOURCE_BY_PATH.put("/AuditController", "AUDIT");
        RESOURCE_BY_PATH.put("/TopupController", "TOPUP");
    }

    private static boolean isPublic(String path) {
        if (PUBLIC_PATHS.contains(path)) {
            return true;
        }
        for (String prefix : PUBLIC_PREFIXES) {
            if (path.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }

    @Override
    public void init(FilterConfig filterConfig) {
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        // public -> device key -> signed in -> permission of the resource
        HttpServletRequest req = (HttpServletRequest) request;
        HttpServletResponse res = (HttpServletResponse) response;
        req.setCharacterEncoding("UTF-8");
        String path = req.getServletPath();

        // 1. pages and files anyone may open
        if (isPublic(path)) {
            chain.doFilter(request, response);
            return;
        }

        try {
            // 2. a device signs with its key; the id comes from the key, never from the body it sends
            if (DEVICE_API_PATHS.contains(path)) {
                Integer deviceId = new DeviceDao().findIdByApiKey(req.getHeader("X-API-Key"));
                if (deviceId == null) {
                    res.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid API key");
                    return;
                }
                req.setAttribute("DEVICE_ID", deviceId);
                chain.doFilter(request, response);
                return;
            }

            // 3. everybody else must be signed in
            User user = Web.currentUser(req);
            if (user == null) {
                res.sendRedirect(req.getContextPath() + "/LoginController");
                return;
            }
            user.setBalance(new dao.UserDao().getBalance(user.getUserId()));

            // 4. and must hold READ (GET) or WRITE (other methods) on the resource behind the path.
            //    A path that is not in the table is refused: forgetting a line is safe, not open.
            Set<String> keys = new PermissionDao().loadKeys(user.getUserId());
            req.setAttribute("perms", keys);   // common/nav.jspf reads it to draw the menu
            String resource = RESOURCE_BY_PATH.get(path);
            if ("/LockerSlotController".equals(path) && "POST".equals(req.getMethod())
                    && "status".equals(Web.trimmed(req, "action"))) {
                resource = "SLOTSTATUS";
            }
            String action = "GET".equals(req.getMethod()) ? "READ" : "WRITE";
            if (resource == null || !keys.contains(resource + ":" + action)) {
                res.sendError(HttpServletResponse.SC_FORBIDDEN, "Permission denied");
                return;
            }
            res.setHeader("Cache-Control", "no-store");   // the Back button must not show a page after logout
            chain.doFilter(request, response);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    public void destroy() {
    }
}
