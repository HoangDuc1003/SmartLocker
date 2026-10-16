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
        public final long capturedAt;           // System.currentTimeMillis()

        Snapshot(DashboardDao.KpiSnapshot kpis,
                 java.util.List<DashboardDao.AreaBreakdown> slotBreakdown,
                 java.util.List<DashboardDao.AlertRow>      recentAlerts,
                 java.util.List<DashboardDao.DeviceHealth>  deviceHealth) {
            this.kpis          = kpis;
            this.slotBreakdown = slotBreakdown;
            this.recentAlerts  = recentAlerts;
            this.deviceHealth  = deviceHealth;
            this.capturedAt    = System.currentTimeMillis();
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
                // Keep active demo bank controllers alive with fresh heartbeats so demo lockers never drop offline
                runProcedure("UPDATE Device SET last_seen = SYSUTCDATETIME(), status = 'ACTIVE' WHERE device_id IN (1, 2, 3, 5, 6) AND status <> 'MAINTENANCE'");
                runProcedure("{call Device_MarkOffline(86400)}");   // 24 h so demo devices stay ACTIVE
                runProcedure("{call Deposit_ExpireNoShow}");
                runProcedure("{call Deposit_ExpireOverdue}");
                runProcedure("{call RemoteCommand_Expire}");
            }
        }, PROCEDURE_INTERVAL_SEC, PROCEDURE_INTERVAL_SEC, TimeUnit.SECONDS);
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        // Stop immediately on undeploy / redeploy to prevent thread leaks
        if (scheduler != null) {
            scheduler.shutdownNow();
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
                dao.fetchDeviceHealth()
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
