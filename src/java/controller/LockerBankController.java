package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Todo;

/** Banks (cabinets) of an area. Add, view, edit, delete. */
@WebServlet(name = "LockerBankController", urlPatterns = {"/LockerBankController"})
public class LockerBankController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/lockerBank.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO list with search(...) and count(...): the keyword, filters and ?page= from the request, set items, total, page, pages for the view; action=new and action=edit&id= show the form; action=export writes a CSV with util.Csv
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("LockerBankController.doPost: action=create|update|delete: read the form, validate on the server, write through the dao, AuditDao.append, Web.flash, then redirect (Post/Redirect/Get). A delete the database refuses shows the reason the dao returns");
    }
}
