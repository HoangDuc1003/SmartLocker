package dao;

import util.Todo;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

/**
 * Builds the JSON of the locker map page: the areas for the menu, the banks and slots of one area.
 * Everything a role must not see (names of other users, alerts, tickets) is left out here, on the server.
 */
public class LockerMapDao {

    // TODO helpers (fields, constants, private methods) used by the demos in the guide: UTC text for the browser

    /**
     * @param areaCode  the area to draw; empty or unknown means the first area that has slots
     * @param userId    the signed-in user, used for the "mine" flag
     * @param staff     true for roles that may see who uses a slot and its alerts
     */
    public JsonObject load(String areaCode, int userId, boolean staff) throws SQLException {
        throw Todo.of("LockerMapDao.load: four queries: areas, plans, banks of the area, slots of the area; the JSON matches the frontend");
    }
}
