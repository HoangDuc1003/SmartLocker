package controller;

import dao.AuditDao;
import dao.LockerBankDao;
import dao.LockerSlotDao;
import java.io.IOException;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import model.LockerSlot;
import model.User;
import util.Csv;
import util.Todo;
import util.Web;

/**
 * Add, view, edit and delete door slots. The pattern of every CRUD controller:
 * GET shows a list or a form, POST changes data then redirects (Post/Redirect/Get),
 * the message for the next page travels in the session as a flash.
 */
@WebServlet(name = "LockerSlotController", urlPatterns = {"/LockerSlotController"})
public class LockerSlotController extends HttpServlet {

    private static final String VIEW = "/WEB-INF/views/lockerSlot.jsp";

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: constants, the list and form pages, the CSV export, form reading and validation

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        // action = new | edit | export, anything else is the list
        req.getRequestDispatcher(VIEW).forward(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        throw Todo.of("LockerSlotController.doPost: action = create | update | delete; validate, write, audit, flash, redirect");
    }
}
