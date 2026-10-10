package dao;

import java.sql.SQLException;
import java.util.List;
import model.Calibration;
import util.Todo;

/** Calibration of a sensor on a device. A new version is a new row, old rows stay as history. */
public class CalibrationDao {

    public List<Calibration> search(Integer deviceId, int page, int size) throws SQLException {
        throw Todo.of("Calibration JOIN Device JOIN SensorType, ORDER BY device, sensor, version DESC, OFFSET/FETCH");
    }

    public int count(Integer deviceId) throws SQLException {
        throw Todo.of("SELECT COUNT(*) with the same filter");
    }

    public Calibration findById(int calibId) throws SQLException {
        throw Todo.of("one row by id");
    }

    /** Adds the next version for the device and sensor: MAX(version) + 1. */
    public int insert(Calibration c) throws SQLException {
        throw Todo.of("INSERT with version = ISNULL(MAX(version),0)+1 for the same device and sensor_type_id");
    }

    public boolean update(Calibration c) throws SQLException {
        throw Todo.of("UPDATE offset_val, scale_val, valid_until");
    }

    public String delete(int calibId) throws SQLException {
        throw Todo.of("DELETE; return a reason if it fails");
    }

    /** Dropdown data: sensor types as {id, name}. */
    public List<String[]> sensorTypes() throws SQLException {
        throw Todo.of("SELECT sensor_type_id, name FROM SensorType");
    }
}
