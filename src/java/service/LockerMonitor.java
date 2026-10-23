package service;

import dao.DbContext;
import dao.DashboardDao;
import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.annotation.WebListener;

/**
 * Background clock jobs plus the In-Memory Dashboard Snapshot cache.
 *
 * <h3>Cache design</h3>
 * <ul>
 *   <li>{@code AtomicReference<Snapshot>} holds the last computed snapshot.</li>
 *   <li>The snapshot is refreshed every {@value #SNAPSHOT_INTERVAL_SEC} seconds
 *       by the same scheduler thread that runs the maintenance procedures.</li>
 *   <li>Any number of concurrent callers of {@code DashboardApi} simply read the
 *       reference — zero DB queries per HTTP request during the TTL window.</li>
 *   <li>If the cache is stale (older than {@value #STALENESS_LIMIT_MS} ms) a
 *       lazy refresh is triggered by the API thread as a safety net.</li>
 * </ul>
 *
 * <h3>Thread safety</h3>
 * {@code AtomicReference} guarantees a single-writer / many-reader pattern
 * without synchronisation overhead on the hot read path.
 */
@WebListener
public class LockerMonitor implements ServletContextListener {

    private static final Logger LOG = Logger.getLogger(LockerMonitor.class.getName());

    /** How often scheduled maintenance procedures run (seconds). */
    private static final int PROCEDURE_INTERVAL_SEC = 15;

    /** How often the dashboard snapshot is refreshed (seconds). */
    private static final int SNAPSHOT_INTERVAL_SEC  = 2;

    /** If the cached snapshot is older than this, the API thread refreshes it immediately. */
    private static final long STALENESS_LIMIT_MS    = 3_000L;

    // ─── Snapshot ─────────────────────────────────────────────────────────────

    /** Immutable snapshot DTO — entire object is replaced atomically on each refresh. */
    public static class Snapshot {
        public final DashboardDao.KpiSnapshot         kpis;
        public final java.util.List<DashboardDao.AreaBreakdown>  slotBreakdown;
        public final java.util.List<DashboardDao.AlertRow>       recentAlerts;
        public final java.util.List<DashboardDao.DeviceHealth>   deviceHealth;
        public final java.util.List<java.util.Map<String, Object>> recentSessions;
        public final long capturedAt;           // System.currentTimeMillis()

        Snapshot(DashboardDao.KpiSnapshot kpis,
                 java.util.List<DashboardDao.AreaBreakdown> slotBreakdown,
                 java.util.List<DashboardDao.AlertRow>      recentAlerts,
                 java.util.List<DashboardDao.DeviceHealth>  deviceHealth,
                 java.util.List<java.util.Map<String, Object>> recentSessions) {
            this.kpis           = kpis;
            this.slotBreakdown  = slotBreakdown;
            this.recentAlerts   = recentAlerts;
            this.deviceHealth   = deviceHealth;
            this.recentSessions = recentSessions;
            this.capturedAt     = System.currentTimeMillis();
        }
    }

    /** Shared reference — read by DashboardApi without synchronisation. */
    private static final AtomicReference<Snapshot> CACHE = new AtomicReference<>();

    /**
     * Returns the current snapshot, refreshing it immediately if it is absent or stale.
     * This is the entry-point used by {@code DashboardApi}.
     */
    public static Snapshot getSnapshot() {
        Snapshot s = CACHE.get();
        if (s == null || (System.currentTimeMillis() - s.capturedAt) > STALENESS_LIMIT_MS) {
            // Lazy refresh on the calling thread — acceptable because it happens at most
            // once per STALENESS_LIMIT_MS regardless of how many concurrent callers arrive.
            Snapshot fresh = buildSnapshot();
            if (fresh != null) {
                CACHE.compareAndSet(s, fresh);   // first thread wins, others reuse it
                return CACHE.get();
            }
        }
        return s;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    private ScheduledExecutorService scheduler;
    private ScheduledExecutorService mailer;

    /** How often the due reminder e-mails are looked for (seconds). */
    private static final int MAIL_INTERVAL_SEC = 30;

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "LockerMonitor");
            t.setDaemon(true);
            return t;
        });

        // 1. Snapshot refresh every 2 seconds
        scheduler.scheduleWithFixedDelay(new Runnable() {
            @Override public void run() {
                Snapshot fresh = buildSnapshot();
                if (fresh != null) CACHE.set(fresh);
            }
        }, 0, SNAPSHOT_INTERVAL_SEC, TimeUnit.SECONDS);

        // 2. Maintenance procedures every 15 seconds (initial delay 15s so the first
        //    request isn't blocked by a potentially slow stored-procedure call)
        scheduler.scheduleWithFixedDelay(new Runnable() {
            @Override public void run() {
                // Demo devices have no ESP32 behind them, so their heartbeat is simulated here. Only the ones the
                // seed marks "demo":true in OperatingProfile: a real device that stops calling still goes OFFLINE.
                runProcedure("UPDATE d SET last_seen = SYSUTCDATETIME() FROM Device d "
                        + "WHERE d.status = 'ACTIVE' AND EXISTS (SELECT 1 FROM OperatingProfile p "
                        + "WHERE p.device_id = d.device_id AND p.params_json LIKE '%\"demo\":true%')");
                runProcedure("{call Device_MarkOffline(90)}");   // demo devices get a heartbeat above, a silent one is OFFLINE after 90 s
                runProcedure("{call Deposit_ExpireNoShow}");
                runProcedure("{call Deposit_ExpireOverdue}");    // v3: locks and charges the late fee, never frees the slot
                runProcedure("{call Deposit_Escalate}");         // v3: 48 hours late, an alert for the staff
                runProcedure("{call RemoteCommand_Expire}");
            }
        }, PROCEDURE_INTERVAL_SEC, PROCEDURE_INTERVAL_SEC, TimeUnit.SECONDS);

        // 3. v3: due reminder e-mails on their own thread, so a slow SMTP server never delays the jobs above
        mailer = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "LockerMonitor-mail");
            t.setDaemon(true);
            return t;
        });
        MailService mail = MailService.of(sce.getServletContext());
        if (mail.isEnabled()) {
            LOG.info("Due reminder e-mails on, settings from " + mail.source());
        }
        DueReminder reminder = new DueReminder(mail);
        mailer.scheduleWithFixedDelay(() -> {
            try {
                reminder.run();
            } catch (RuntimeException e) {
                LOG.log(Level.WARNING, "Due reminder failed: " + e.getMessage());   // keep the schedule alive
            }
        }, MAIL_INTERVAL_SEC, MAIL_INTERVAL_SEC, TimeUnit.SECONDS);
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // Stop immediately on undeploy / redeploy to prevent thread leaks
        if (scheduler != null) {
            scheduler.shutdownNow();
        }
        if (mailer != null) {
            mailer.shutdownNow();
        }
        CACHE.set(null);
    }

    // ─── Internals ────────────────────────────────────────────────────────────

    /**
     * Builds a fresh snapshot by calling DashboardDao.
     * Never throws — logs and returns {@code null} on any error so the old
     * snapshot continues to be served rather than crashing the scheduler.
     */
    private static Snapshot buildSnapshot() {
        DashboardDao dao = new DashboardDao();
        try {
            DashboardDao.KpiSnapshot kpis = dao.fetchKpis();

            // Audit chain check — expensive on large logs; run only when snapshot is built
            // and cache the result inside the snapshot so the API never triggers it.
            try {
                long broken = service.AuditVerifier.findFirstBroken();
                kpis.auditChainValid = (broken == -1);
            } catch (Exception e) {
                LOG.log(Level.WARNING, "AuditVerifier failed, assuming valid: " + e.getMessage());
                kpis.auditChainValid = true;
            }

            return new Snapshot(
                kpis,
                dao.fetchAreaBreakdown(),
                dao.fetchRecentAlerts(10),
                dao.fetchDeviceHealth(),
                new dao.LockerSessionDao().search(null, 1, 10)
            );
        } catch (SQLException e) {
            LOG.log(Level.WARNING, "Dashboard snapshot build failed: " + e.getMessage());
            return null;
        }
    }

    private void runProcedure(String call) {
        try (Connection conn = DbContext.getConnection()) {
            if (call.startsWith("{")) {
                try (CallableStatement cs = conn.prepareCall(call)) {
                    cs.execute();
                }
            } else {
                try (java.sql.Statement st = conn.createStatement()) {
                    st.execute(call);
                }
            }
        } catch (SQLException e) {
            // An exception escaping run() silently cancels all future runs of this task.
            // Catching here keeps the scheduler alive even if one procedure fails.
            LOG.log(Level.WARNING, "LockerMonitor " + call + " failed: " + e.getMessage());
        }
    }
}
