package dao;

import java.sql.SQLException;
import java.util.List;
import model.LockerArea;
import util.Todo;

/** Areas: Library, Dormitory ... Write it like LockerSlotDao. */
public class LockerAreaDao {

    /** Every area with its slot count and user count, ordered by code. The list page and the drop-downs use it. */
    public List<LockerArea> listAll() throws SQLException {
        throw Todo.of("SELECT area columns, a subquery COUNT of slots (LockerBank join LockerSlot) and of users (Users.area_id)");
    }

    public LockerArea findById(int areaId) throws SQLException {
        throw Todo.of("one area by id");
    }

    public int insert(LockerArea a) throws SQLException {
        throw Todo.of("INSERT area_code, name, location, is_active with RETURN_GENERATED_KEYS");
    }

    public boolean update(LockerArea a) throws SQLException {
        throw Todo.of("UPDATE name, location, is_active; the code may change too");
    }

    /** null when deleted, otherwise the reason: banks or users still point to the area (SQL error 547). */
    public String delete(int areaId) throws SQLException {
        throw Todo.of("DELETE, catch 547 and return a readable reason");
    }

    public boolean codeExists(String areaCode, int exceptAreaId) throws SQLException {
        throw Todo.of("SELECT COUNT(*) FROM LockerArea WHERE area_code = ? AND area_id <> ?");
    }
}
