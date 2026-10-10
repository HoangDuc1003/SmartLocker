package dao;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import model.Deposit;
import util.Todo;

/** Bookings and deposits. The state changes are stored procedures, the lists are plain queries. */
public class DepositDao {

    /** Case 4: books a slot for the user. The procedure throws a readable error when it cannot (50030 to 50035). */
    public long reserve(int userId, int slotId, int planId) throws SQLException {
        // {call Deposit_Reserve(?, ?, ?, ?)} with a BIGINT OUTPUT parameter
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Reserve(?, ?, ?, ?)}")) {
            cs.setInt(1, userId);
            cs.setInt(2, slotId);
            cs.setInt(3, planId);
            cs.registerOutParameter(4, Types.BIGINT);
            cs.execute();
            return cs.getLong(4);
        }
    }

    public void cancel(long depositId, int userId) throws SQLException {
        // {call Deposit_Cancel(?, ?)}
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_Cancel(?, ?)}")) {
            cs.setLong(1, depositId);
            cs.setInt(2, userId);
            cs.execute();
        }
    }

    /** Online extension: moves due_at forward, at most 3 times. */
    public void extend(long depositId, int minutes, int userId) throws SQLException {
        throw Todo.of("{call Deposit_Extend(?, ?, ?)} like cancel()");
    }

    /** The heartbeat says this slot now holds something: the clock of a reserved booking starts. */
    public void checkIn(int deviceId, String slotCode) throws SQLException {
        // {call Deposit_CheckIn(?, ?)}
        try (Connection conn = DbContext.getConnection();
             CallableStatement cs = conn.prepareCall("{call Deposit_CheckIn(?, ?)}")) {
            cs.setInt(1, deviceId);
            cs.setString(2, slotCode);
            cs.execute();
        }
    }

    /** A session ended: the booking is completed and the slot is free again. */
    public void complete(int deviceId, String slotCode) throws SQLException {
        throw Todo.of("{call Deposit_Complete(?, ?)} like checkIn()");
    }

    /** For the heartbeat reply: which card may open which reserved slot of this device. Keys: slot_code, card_uid. */
    public List<Map<String, String>> reservedFor(int deviceId) throws SQLException {
        // RESERVED deposits of the device with the uid of the card
        String sql = "SELECT s.slot_code, c.card_uid FROM Deposit d "
                + "JOIN LockerSlot s ON s.locker_slot_id = d.slot_id "
                + "JOIN LockerBank b ON b.bank_id = s.bank_id "
                + "JOIN UserCard c ON c.card_id = d.card_id "
                + "WHERE b.device_id = ? AND d.status = 'RESERVED'";
        List<Map<String, String>> list = new ArrayList<>();
        try (Connection conn = DbContext.getConnection(); PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, deviceId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    Map<String, String> row = new LinkedHashMap<>();
                    row.put("slot_code", rs.getString(1));
                    row.put("card_uid", rs.getString(2));
                    list.add(row);
                }
            }
        }
        return list;
    }

    /** The bookings of one user, newest first: the My bookings page. */
    public List<Deposit> listByUser(int userId) throws SQLException {
        throw Todo.of("Deposit JOIN LockerSlot JOIN LockerBank JOIN StoragePlan WHERE user_id = ? ORDER BY reserved_at DESC");
    }

    /** One page for staff. keyword matches username or slot code; status = "" for all. */
    public List<Deposit> search(String keyword, String status, int page, int size) throws SQLException {
        throw Todo.of("same joins as listByUser plus Users, optional filters, OFFSET/FETCH");
    }

    public int count(String keyword, String status) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filters");
    }

    public Deposit findById(long depositId) throws SQLException {
        throw Todo.of("one deposit by id");
    }

    /** Staff registers a deposit for a walk-in user. Keep the unique indexes of the table in mind. */
    public long insert(Deposit d) throws SQLException {
        throw Todo.of("INSERT user_id, slot_id, plan_id, card_id, status, started_at, due_at; the slot becomes OCCUPIED in the same transaction");
    }

    /** Staff changes the plan or the due time. */
    public boolean update(Deposit d) throws SQLException {
        throw Todo.of("UPDATE plan_id, due_at, status");
    }

    /** null when deleted, otherwise the reason. Only a booking that is not open may be deleted. */
    public String delete(long depositId) throws SQLException {
        throw Todo.of("DELETE only when status is COMPLETED, NO_SHOW or CANCELLED");
    }
}
