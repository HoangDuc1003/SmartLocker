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
        throw Todo.of("DepositDao.reserve: {call Deposit_Reserve(?, ?, ?, ?)} with a BIGINT OUTPUT parameter");
    }

    public void cancel(long depositId, int userId) throws SQLException {
        throw Todo.of("DepositDao.cancel: {call Deposit_Cancel(?, ?)}");
    }

    /** Online extension: moves due_at forward, at most 3 times. */
    public void extend(long depositId, int minutes, int userId) throws SQLException {
        throw Todo.of("{call Deposit_Extend(?, ?, ?)} like cancel()");
    }

    /** The heartbeat says this slot now holds something: the clock of a reserved booking starts. */
    public void checkIn(int deviceId, String slotCode) throws SQLException {
        throw Todo.of("DepositDao.checkIn: {call Deposit_CheckIn(?, ?)}");
    }

    /** A session ended: the booking is completed and the slot is free again. */
    public void complete(int deviceId, String slotCode) throws SQLException {
        throw Todo.of("{call Deposit_Complete(?, ?)} like checkIn()");
    }

    /** For the heartbeat reply: which card may open which reserved slot of this device. Keys: slot_code, card_uid. */
    public List<Map<String, String>> reservedFor(int deviceId) throws SQLException {
        throw Todo.of("DepositDao.reservedFor: RESERVED deposits of the device with the uid of the card");
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
