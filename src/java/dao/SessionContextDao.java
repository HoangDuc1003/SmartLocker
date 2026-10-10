package dao;

import util.Todo;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import model.LockerSession;
import service.SessionContext;

/**
 * Loads everything the rules need besides the session itself: valid ranges, calibration,
 * clock difference, the remote command, the card and the booking.
 * Call it after the session is stored, because some queries read the stored row by session_id.
 */
public class SessionContextDao {

    public SessionContext load(LockerSession s) throws SQLException {
        throw Todo.of("SessionContextDao.load: six short queries, one per field of the context");
    }
}
