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

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: public paths, device paths and the path to resource table

    @Override
    public void init(FilterConfig filterConfig) {
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        // public -> device key -> signed in -> permission of the resource
        chain.doFilter(request, response);   // the skeleton lets everything through until you write the checks
    }

    @Override
    public void destroy() {
    }
}
