package dao;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/** The only place that opens a database connection. Copied from the assignment, Workshop 1 step 3. */
public class DbContext {

    // change the host here when the machine or the network changes
    private static final String URL =
            "jdbc:sqlserver://localhost:1433;databaseName=PRJ301_LOCKER;encrypt=false";
    private static final String USER = "sa";
    private static final String PASSWORD = "12345";   // the password of your own sa account

    public static Connection getConnection() throws SQLException {
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("SQL Server JDBC driver not found in WEB-INF/lib", e);
        }
        return DriverManager.getConnection(URL, USER, PASSWORD);
    }
}
