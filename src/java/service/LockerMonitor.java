package service;

import dao.DbContext;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

/** Jobs that run by the clock, not because someone clicked: offline devices, no-shows, expired commands. */
@WebListener
public class LockerMonitor implements ServletContextListener {

    private static final Logger LOG = Logger.getLogger(LockerMonitor.class.getName());
    private ScheduledExecutorService scheduler;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        // one thread, every 30 seconds: Device_MarkOffline, Deposit_ExpireNoShow, RemoteCommand_Expire
        // TODO nothing runs yet: start the scheduler here (a listener that throws would stop the whole application from starting)
    }

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: one failing call must not stop the others, or the timer

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // NetBeans redeploys often: stop the thread or every redeploy leaks one
        // TODO stop the scheduler here
    }
}
