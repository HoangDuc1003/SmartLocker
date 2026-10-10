package dao;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import model.LockerSlot;
import util.Todo;

/**
 * The model of every CRUD dao in this project: search with paging, count, find one, insert, update, delete.
 * Read this class first, then write StoragePlanDao, LockerBankDao ... the same way.
 */
public class LockerSlotDao {

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: the SELECT, the row mapper and the shared WHERE clause

    /** One page, page starts at 1. The ORDER BY is required by OFFSET ... FETCH. */
    public List<LockerSlot> search(String keyword, Integer bankId, String status, int page, int size) throws SQLException {
        throw Todo.of("LockerSlotDao.search: server side paging: only the rows of the page leave the database");
    }

    public int count(String keyword, Integer bankId, String status) throws SQLException {
        throw Todo.of("LockerSlotDao.count: the same WHERE, so the page count matches the rows");
    }

    /** null when there is no such slot. */
    public LockerSlot findById(int slotId) throws SQLException {
        throw Todo.of("LockerSlotDao.findById");
    }

    /** Returns the new id. */
    public int insert(LockerSlot s) throws SQLException {
        throw Todo.of("LockerSlotDao.insert: INSERT ... with RETURN_GENERATED_KEYS");
    }

    public boolean update(LockerSlot s) throws SQLException {
        throw Todo.of("LockerSlotDao.update: UPDATE ... WHERE locker_slot_id = ?, true when one row changed");
    }

    /** null when deleted, otherwise the reason it could not be deleted, shown to the user as it is. */
    public String delete(int slotId) throws SQLException {
        throw Todo.of("LockerSlotDao.delete: catch SQL error 547 (foreign key) and return a readable reason instead of failing");
    }

    /** exceptSlotId = 0 when creating. */
    public boolean codeExists(int bankId, String slotCode, int exceptSlotId) throws SQLException {
        throw Todo.of("SELECT COUNT(*) FROM LockerSlot WHERE bank_id = ? AND slot_code = ? AND locker_slot_id <> ?");
    }
}
