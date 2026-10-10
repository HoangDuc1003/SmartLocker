package dao;

import java.sql.SQLException;
import java.util.List;
import model.StoragePlan;
import util.Todo;

/** Storage plans: 2 hours, 4 hours, the 2 minute demo plan. Write it like LockerSlotDao. */
public class StoragePlanDao {

    /** activeOnly = true for the booking form, false for the management page. */
    public List<StoragePlan> listAll(boolean activeOnly) throws SQLException {
        throw Todo.of("SELECT all plans ORDER BY duration_min, optionally WHERE is_active = 1");
    }

    public StoragePlan findById(int planId) throws SQLException {
        throw Todo.of("one plan by id");
    }

    public int insert(StoragePlan p) throws SQLException {
        throw Todo.of("INSERT plan_name, duration_min, grace_min, price, is_active");
    }

    public boolean update(StoragePlan p) throws SQLException {
        throw Todo.of("UPDATE the same columns");
    }

    /** null when deleted, otherwise the reason: a plan used by a booking cannot be deleted (547); deactivate it instead. */
    public String delete(int planId) throws SQLException {
        throw Todo.of("DELETE, catch 547 and return a readable reason");
    }
}
