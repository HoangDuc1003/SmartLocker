package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import util.Todo;

/** Case 5: maintenance tickets. */
public class MaintenanceDao {

    /**
     * Opens one ticket for the device (not a second one while one is open), gives it to the least busy
     * technician and puts the slot of the session out of service.
     */
    public void openForFault(int deviceId, int alertId, long sessionId, String note) throws SQLException {
        throw Todo.of("MaintenanceDao.openForFault: {call Ticket_OpenForFault(?, ?, ?, ?)}");
    }

    /** The technician fixed it: closes the ticket, gives the slot back, resolves the alert. */
    public void close(int ticketId, int actorId, String note) throws SQLException {
        throw Todo.of("{call Ticket_Close(?, ?, ?)} like openForFault()");
    }

    /** Keys: ticket_id, alert_id, device_code, assigned_to_name, note, status, opened_at, closed_at. */
    public List<Map<String, Object>> search(String status, int page, int size) throws SQLException {
        throw Todo.of("MaintenanceTicket JOIN Device JOIN Users (assigned_to), optional status, ORDER BY ticket_id DESC, OFFSET/FETCH");
    }

    public int count(String status) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filter");
    }
}
