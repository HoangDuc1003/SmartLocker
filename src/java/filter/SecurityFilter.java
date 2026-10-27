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
@WebFilter(urlPatterns = {"/*"}, dispatcherTypes = {
        javax.servlet.DispatcherType.REQUEST,
        javax.servlet.DispatcherType.ERROR
})
public class SecurityFilter implements Filter {

    /** Reachable without signing in. */
    private static final Set<String> PUBLIC_PATHS = new HashSet<>(Arrays.asList(
            "/favicon.ico", "/LoginController", "/RegisterController", "/LogoutController",
            "/k", "/api/kiosk/unlock"));                 // v2 phone page (a /k/* servlet has servlet path "/k"): the PIN is the secret, the box lockout limits guesses
    /** v4: a visitor who is not signed in may open the map (GET only); the booking forms need a login (popup on the page). */
    private static final Set<String> GUEST_PATHS = new HashSet<>(Arrays.asList("/LockerMapController", "/api/locker-map"));
    private static final String[] PUBLIC_PREFIXES = {"/css/", "/js/", "/img/", "/k/"};

    /** The device signs with an X-API-Key header instead of a login. */
    private static final Set<String> DEVICE_API_PATHS = new HashSet<>(Arrays.asList(
            "/api/health", "/api/locker/batch",
            "/api/device/auth", "/api/device/enroll/start", "/api/device/enroll/finish"));

    /** servlet path -> resource name in the Permissions table. GET needs READ, anything else needs WRITE. */
    private static final Map<String, String> RESOURCE_BY_PATH = new HashMap<>();

    static {
        RESOURCE_BY_PATH.put("/LockerMapController", "MAP");
        RESOURCE_BY_PATH.put("/api/locker-map", "MAP");
        RESOURCE_BY_PATH.put("/DashboardController", "ALERT");
        RESOURCE_BY_PATH.put("/api/dashboard", "ALERT");
        RESOURCE_BY_PATH.put("/api/dashboard/stats", "ALERT");
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
        RESOURCE_BY_PATH.put("/api/my-locker", "BOOKING");
        RESOURCE_BY_PATH.put("/MyLockerController", "BOOKING");
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

    /** 401 as JSON: the box prints "message" on its OLED. */
    private static void deviceUnauthorized(HttpServletResponse res) throws IOException {
        res.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        res.setContentType("application/json;charset=UTF-8");
        res.getWriter().write("{\"result\":\"ERROR\",\"reason\":\"BAD_API_KEY\",\"message\":\"Sai khoa thiet bi\"}");
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
        res.setCharacterEncoding("UTF-8");
        String path = req.getServletPath();
        // the browser revalidates css/js on each load (a 304 when unchanged), so a redeploy is never hidden by a stale copy;
        // the vendored libraries (Leaflet, Motion: about 300 KB) only change with an upgrade, so they are kept a day
        if (path.startsWith("/js/vendor/")) {
            res.setHeader("Cache-Control", "public, max-age=86400");
        } else if (path.endsWith(".css") || path.endsWith(".js")) {
            res.setHeader("Cache-Control", "no-cache");
        }

        // 0. the address of the app opens the map at once (no landing page, no login page)
        if ("/".equals(path) || "/index.html".equals(path)) {
            res.sendRedirect(req.getContextPath() + "/LockerMapController");
            return;
        }

        // 1. pages and files anyone may open
        if (isPublic(path)) {
            chain.doFilter(request, response);
            return;
        }

        // 1b. Error page dispatch (404, 403, 500) or internal view dispatch - populate perms if signed in, but never block
        if (req.getAttribute("javax.servlet.error.status_code") != null || path.startsWith("/WEB-INF/")) {
            User user = Web.currentUser(req);
            if (user != null) {
                try {
                    user.setBalance(new dao.UserDao().getBalance(user.getUserId()));
                    Set<String> keys = new dao.PermissionDao().loadKeys(user.getUserId());
                    req.setAttribute("perms", keys);
                } catch (SQLException ignored) {}
            }
            chain.doFilter(request, response);
            return;
        }

        try {
            // 2. a device signs with its key; the id comes from the key, never from the body it sends
            if (DEVICE_API_PATHS.contains(path)) {
                String apiKey = req.getHeader("X-API-Key");
                if (apiKey != null) {
                    Integer deviceId = new DeviceDao().findIdByApiKey(apiKey);
                    if (deviceId == null) {
                        deviceUnauthorized(res);
                        return;
                    }
                    req.setAttribute("DEVICE_ID", deviceId);
                    chain.doFilter(request, response);
                    return;
                }
                // an admin may check the health of the server (DB status) from the browser, without a device key
                if ("GET".equalsIgnoreCase(req.getMethod()) && "/api/health".equals(path)) {
                    User user = Web.currentUser(req);
                    if (user != null && "ADMIN".equals(user.getRoleName())) {
                        chain.doFilter(request, response);
                        return;
                    }
                }
                deviceUnauthorized(res);
                return;
            }

            // 3. everybody else must be signed in
            User user = Web.currentUser(req);
            if (user == null) {
                if ("GET".equalsIgnoreCase(req.getMethod()) && GUEST_PATHS.contains(path)) {
                    req.setAttribute("perms", new HashSet<>(Arrays.asList("MAP:READ")));   // the menu shows the map only
                    res.setHeader("Cache-Control", "no-store");
                    chain.doFilter(request, response);
                    return;
                }
                // the map opens the sign-in popup; a page (not an API answer) asked for with GET is opened after it
                String query = req.getQueryString();
                String next = "GET".equalsIgnoreCase(req.getMethod()) && !path.startsWith("/api/")
                        ? path + (query == null ? "" : "?" + query) : null;
                res.sendRedirect(Web.signInUrl(req, "login", next));
                return;
            }
            // the session copy is refreshed on every request: a locked or deleted account is signed out at once,
            // and a changed role takes effect without a new login (controllers read the role from the session)
            User fresh = new dao.UserDao().findById(user.getUserId());
            if (fresh == null || !"ACTIVE".equals(fresh.getStatus())) {
                req.getSession().invalidate();
                res.sendRedirect(Web.signInUrl(req, "login", null));
                return;
            }
            user.setStatus(fresh.getStatus());
            user.setRoleName(fresh.getRoleName());
            user.setRoleRank(fresh.getRoleRank());
            user.setAreaId(fresh.getAreaId());
            user.setAreaCode(fresh.getAreaCode());
            user.setBalance(fresh.getBalance());

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
