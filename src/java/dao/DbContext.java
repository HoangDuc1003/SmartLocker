package dao;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.ArrayDeque;
import java.util.Deque;

/**
 * The only place that opens a database connection. Keeps a small pool of idle connections: a DAO still closes its
 * connection with try-with-resources, and close() hands it back to the pool instead of logging out of SQL Server
 * (a map poll used to open 6 connections, a popup 9). A connection comes back reset (open transaction rolled back,
 * auto-commit on); one idle for a while is checked before it is lent again, one idle too long is closed.
 */
public class DbContext {

    // DB_URL / DB_USER / DB_PASSWORD come from the environment on a hosted server (docs/deploy-render.md);
    // without them the local demo machine is used
    private static final String URL = env("DB_URL",
            "jdbc:sqlserver://localhost:1433;databaseName=PRJ301_LOCKER;encrypt=false");
    private static final String USER = env("DB_USER", "sa");
    private static final String PASSWORD = env("DB_PASSWORD", "12345");   // local SQL Server sa account (demo machine)

    private static final int MAX_IDLE = 8;                    // more borrowers at once still get a new connection
    private static final long CHECK_AFTER_MS = 30_000;        // idle longer than this: isValid() before lending it
    private static final long CLOSE_AFTER_MS = 5 * 60_000;    // idle longer than this: closed (Azure drops idle ones)

    private static final Deque<Idle> IDLE = new ArrayDeque<>();
    private static volatile boolean stopped;   // after shutdown() a returned connection is closed, not kept

    private static final class Idle {
        final Connection raw;
        final long since;

        Idle(Connection raw) {
            this.raw = raw;
            this.since = System.currentTimeMillis();
        }
    }

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.trim().isEmpty() ? fallback : value.trim();
    }

    private static Connection open() throws SQLException {
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("SQL Server JDBC driver not found in WEB-INF/lib", e);
        }
        return DriverManager.getConnection(URL, USER, PASSWORD);
    }

    /** A pooled connection; close() returns it to the pool. */
    public static Connection getConnection() throws SQLException {
        Connection raw = borrowIdle();
        return wrap(raw != null ? raw : open());
    }

    // the newest idle connection that is still usable, or null
    private static Connection borrowIdle() {
        while (true) {
            Idle idle;
            synchronized (IDLE) {
                idle = IDLE.pollFirst();
            }
            if (idle == null) {
                return null;
            }
            long age = System.currentTimeMillis() - idle.since;
            try {
                if (age < CLOSE_AFTER_MS && !idle.raw.isClosed() && (age < CHECK_AFTER_MS || idle.raw.isValid(2))) {
                    return idle.raw;
                }
            } catch (SQLException e) {
                // broken: drop it below
            }
            closeQuietly(idle.raw);
        }
    }

    private static void giveBack(Connection raw) {
        try {
            if (raw.isClosed()) {
                // the driver closes a connection that broke (SQL Server restarted, network cut): the idle ones
                // are most likely broken too, so none of them is lent again
                drain();
                return;
            }
            if (!raw.getAutoCommit()) {
                raw.rollback();          // a DAO that failed half way leaves its transaction open
                raw.setAutoCommit(true);
            }
            raw.clearWarnings();
        } catch (SQLException e) {
            closeQuietly(raw);
            return;
        }
        Idle stale = null;
        synchronized (IDLE) {
            if (!stopped && IDLE.size() < MAX_IDLE) {
                IDLE.addFirst(new Idle(raw));
                raw = null;
            }
            // the newest is lent first, so the oldest waits at the bottom: close it once it is too old
            Idle last = IDLE.peekLast();
            if (last != null && System.currentTimeMillis() - last.since >= CLOSE_AFTER_MS) {
                stale = IDLE.pollLast();
            }
        }
        if (raw != null) {
            closeQuietly(raw);
        }
        if (stale != null) {
            closeQuietly(stale.raw);
        }
    }

    private static void drain() {
        java.util.List<Idle> all;
        synchronized (IDLE) {
            all = new java.util.ArrayList<>(IDLE);
            IDLE.clear();
        }
        for (Idle idle : all) {
            closeQuietly(idle.raw);
        }
    }

    private static Connection wrap(final Connection raw) {
        InvocationHandler handler = new InvocationHandler() {
            private boolean closed;

            @Override
            public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
                String name = method.getName();
                if ("close".equals(name)) {
                    if (!closed) {
                        closed = true;
                        giveBack(raw);
                    }
                    return null;
                }
                if ("isClosed".equals(name)) {
                    return closed || raw.isClosed();
                }
                if (closed) {
                    throw new SQLException("Connection is closed");
                }
                try {
                    return method.invoke(raw, args);
                } catch (InvocationTargetException e) {
                    throw e.getCause();
                }
            }
        };
        return (Connection) Proxy.newProxyInstance(DbContext.class.getClassLoader(),
                new Class<?>[]{Connection.class}, handler);
    }

    private static void closeQuietly(Connection raw) {
        try {
            raw.close();
        } catch (SQLException e) {
            // already gone
        }
    }

    /** Closes the idle connections; called when the app stops (service.LockerMonitor.contextDestroyed). */
    public static void shutdown() {
        stopped = true;
        drain();
    }

    /** CONNECTED, DISCONNECTED or ERROR, for the GET /api/health probe. The connection is closed again at once. */
    public static String ping() {
        try (Connection conn = getConnection()) {
            return conn.isValid(2) ? "CONNECTED" : "DISCONNECTED";
        } catch (SQLException e) {
            return "ERROR";
        }
    }
}
