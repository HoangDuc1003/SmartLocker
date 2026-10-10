package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Todo;

/** Roles and the permission grid. A tick is a row in RolePerm. */
@WebServlet(name = "RoleController", urlPatterns = {"/RoleController"})
public class RoleController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/role.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO no id: PermissionDao.listRoles. id=: PermissionDao.permissionGrid(roleId) for the tick table
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("RoleController.doPost: action=savePerms&roleId=&permIds=...: PermissionDao.saveRolePerms; the administrator keeps ROLE:READ and ROLE:WRITE");
    }
}
