package controller;

import java.io.IOException;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import util.Todo;

/** Alerts: the list, and the detail of one alert with its evidence and the session behind it. */
@WebServlet(name = "AlertController", urlPatterns = {"/AlertController"})
public class AlertController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/alert.jsp";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // TODO no id: list with search/count (status, label filters). id=: AlertDao.findById, set alert, forward to the detail
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("AlertController.doPost: action=resolve&id=: AlertDao.resolve(id, me.getUserId()), flash, redirect to the list");
    }
}
