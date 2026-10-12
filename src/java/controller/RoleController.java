package controller;

import java.io.IOException;
import java.sql.SQLException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

/** Roles and the permission grid. A tick is a row in RolePerm. */
@WebServlet(name = "RoleController", urlPatterns = {"/RoleController"})
public class RoleController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/role.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        dao.PermissionDao dao = new dao.PermissionDao();
        Integer roleId = util.Web.optionalInt(req, "id");
        try {
            if (roleId != null && roleId > 0) {
                String roleName = dao.roleName(roleId);
                if (roleName == null) {
                    util.Web.flash(req.getSession(), "Role not found", true);
                    res.sendRedirect("RoleController");
                    return;
                }
                req.setAttribute("mode", "grid");
                req.setAttribute("roleId", roleId);
                req.setAttribute("roleName", roleName);
                req.setAttribute("grid", dao.permissionGrid(roleId));
            } else {
                req.setAttribute("mode", "list");
                req.setAttribute("roles", dao.listRoles());
            }
            req.getRequestDispatcher(VIEW).forward(req, res);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        model.User me = util.Web.currentUser(req);
        dao.PermissionDao dao = new dao.PermissionDao();
        int roleId = util.Web.intParam(req, "roleId", 0);
        try {
            String roleName = dao.roleName(roleId);
            if (roleName == null) {
                util.Web.flash(req.getSession(), "Role not found", true);
                res.sendRedirect("RoleController");
                return;
            }

            String[] permIdStrs = req.getParameterValues("permIds");
            java.util.Set<Integer> permSet = new java.util.HashSet<>();
            if (permIdStrs != null) {
                for (String s : permIdStrs) {
                    try {
                        permSet.add(Integer.parseInt(s.trim()));
                    } catch (NumberFormatException ignored) {}
                }
            }

            // The administrator role must always retain ROLE:READ and ROLE:WRITE
            if ("ADMIN".equals(roleName)) {
                for (String[] row : dao.permissionGrid(roleId)) {
                    if ("ROLE".equals(row[1]) && ("READ".equals(row[2]) || "WRITE".equals(row[2]))) {
                        permSet.add(Integer.parseInt(row[0]));
                    }
                }
            }

            int[] permIds = new int[permSet.size()];
            int idx = 0;
            for (int pid : permSet) {
                permIds[idx++] = pid;
            }

            dao.saveRolePerms(roleId, permIds);
            new dao.AuditDao().append(me.getUserId(), "UPDATE", "ROLE", roleId, "Saved permissions for role " + roleName);
            util.Web.flash(req.getSession(), "Permissions updated for role " + roleName, false);
            res.sendRedirect("RoleController?id=" + roleId);
        } catch (SQLException e) {
            throw new ServletException(e);
        }
    }
}
