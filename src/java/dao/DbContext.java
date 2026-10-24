package dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/** The only place that opens a database connection. No pool: every DAO call opens one and closes it with try-with-resources. */
public class DbContext {

    // DB_URL / DB_USER / DB_PASSWORD come from the environment on a hosted server (docs/deploy-render.md);
    // without them the local demo machine is used
    private static final String URL = env("DB_URL",
            "jdbc:sqlserver://localhost:1433;databaseName=PRJ301_LOCKER;encrypt=false");
    private static final String USER = env("DB_USER", "sa");
    private static final String PASSWORD = env("DB_PASSWORD", "12345");   // local SQL Server sa account (demo machine)

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.trim().isEmpty() ? fallback : value.trim();
    }

    public static Connection getConnection() throws SQLException {
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("SQL Server JDBC driver not found in WEB-INF/lib", e);
        }
        return DriverManager.getConnection(URL, USER, PASSWORD);
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
