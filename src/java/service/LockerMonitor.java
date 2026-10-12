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
        scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleWithFixedDelay(new Runnable() {
            @Override
            public void run() {
                runProcedure("{call Device_MarkOffline(86400)}");   // 24h timeout so demo devices stay active
                runProcedure("{call Deposit_ExpireNoShow}");
                runProcedure("{call RemoteCommand_Expire}");
            }
        }, 30, 30, TimeUnit.SECONDS);
    }

    private void runProcedure(String call) {
        try (Connection conn = DbContext.getConnection(); CallableStatement cs = conn.prepareCall(call)) {
            cs.execute();
        } catch (SQLException e) {
            // an exception that escapes run() silently cancels every later run, so catch it here
            LOG.log(Level.WARNING, "LockerMonitor " + call + " failed: " + e.getMessage());
        }
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // NetBeans redeploys often: stop the thread or every redeploy leaks one
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
    }
}
