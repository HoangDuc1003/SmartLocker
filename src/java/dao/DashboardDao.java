package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import util.Todo;

/** Numbers for the dashboard cards and the live chart. */
public class DashboardDao {

    /** The last sessions of a device, oldest first so a chart can draw them left to right. Keys: time, a, b. */
    public List<Map<String, Object>> recentSessions(int deviceId, int limit) throws SQLException {
        throw Todo.of("DashboardDao.recentSessions: TOP (?) newest first in SQL, then reversed in Java");
    }

    /** Counts for the cards: free, inUse, overdue, openAlerts, offlineDevices. */
    public Map<String, Integer> lockerCounts() throws SQLException {
        throw Todo.of("one query on v_LockerSlotMap grouped by display_status, plus COUNT of OPEN alerts and OFFLINE devices");
    }
}
