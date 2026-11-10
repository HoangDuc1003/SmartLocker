package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertNull;
import static org.testng.Assert.assertTrue;

import controller.LockerSessionController;
import dao.LockerSessionDao;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.Map;
import org.testng.SkipException;
import org.testng.annotations.Test;

/**
 * The "Dữ liệu cảm biến" list: the Vietnam dates of the filter become UTC bounds, and the DAO filters, sorts and
 * escapes the keyword. The database part only reads, and is skipped when the database is not there.
 */
public class LockerSessionListTest {

    @Test
    public void vietnamMidnightIsFivePmUtcOfTheDayBefore() {
        assertEquals(LockerSessionController.startOfDayUtc(LocalDate.of(2026, 11, 10)), "2026-11-09 17:00:00");
        assertEquals(LockerSessionController.startOfDayUtc(LocalDate.of(2026, 1, 1)), "2025-12-31 17:00:00");
        assertNull(LockerSessionController.startOfDayUtc(null));
    }

    @Test
    public void datesParseOrFail() {
        assertNull(LockerSessionController.parseDate(""));
        assertNull(LockerSessionController.parseDate(null));
        assertEquals(LockerSessionController.parseDate("2026-11-10"), LocalDate.of(2026, 11, 10));
    }

    @Test
    public void yearsOutsideTheDatabaseRangeAreRefused() {
        assertTrue(LockerSessionController.inRange(null));
        assertTrue(LockerSessionController.inRange(LocalDate.of(2026, 11, 10)));
        assertFalse(LockerSessionController.inRange(LocalDate.of(10000, 1, 1)));
        assertFalse(LockerSessionController.inRange(LocalDate.of(1, 1, 1)));
    }

    @Test(expectedExceptions = DateTimeParseException.class)
    public void aBadDateIsRefused() {
        LockerSessionController.parseDate("10/11/2026");
    }

    private static int count(LockerSessionDao.Filter f) {
        try {
            return new LockerSessionDao().count(f);
        } catch (SQLException e) {
            throw new SkipException("Database not available: " + e.getMessage());
        }
    }

    @Test
    public void filtersNarrowTheListAndWildcardsAreLiteral() throws SQLException {
        LockerSessionDao.Filter all = new LockerSessionDao.Filter();
        int total = count(all);
        if (total == 0) {
            throw new SkipException("No sessions in the database");
        }
        LockerSessionDao.Filter future = new LockerSessionDao.Filter();
        future.fromUtc = "2999-01-01 00:00:00";
        assertEquals(count(future), 0);
        LockerSessionDao.Filter percent = new LockerSessionDao.Filter();
        percent.q = "%";                                  // a literal percent sign, not "everything"
        assertEquals(count(percent), 0);
        LockerSessionDao.Filter box = new LockerSessionDao.Filter();
        box.q = "LOCKER-";
        assertEquals(count(box), total);                  // every session belongs to a box named LOCKER-..
    }

    @Test
    public void sortByWeightAscending() throws SQLException {
        LockerSessionDao.Filter f = new LockerSessionDao.Filter();
        f.sort = "weight";
        f.desc = false;
        if (count(f) == 0) {
            throw new SkipException("No sessions in the database");
        }
        List<Map<String, Object>> rows = new LockerSessionDao().list(f, 1, 50);
        for (int i = 1; i < rows.size(); i++) {
            assertTrue((Double) rows.get(i - 1).get("weight_delta_g") <= (Double) rows.get(i).get("weight_delta_g"),
                    "row " + i + " is out of order");
        }
    }

    @Test
    public void anUnknownSortKeyFallsBackToTheMeasuredTime() throws SQLException {
        LockerSessionDao.Filter f = new LockerSessionDao.Filter();
        f.sort = "measured_at; DROP TABLE Users";          // never reaches ORDER BY
        if (count(f) == 0) {
            throw new SkipException("No sessions in the database");
        }
        assertTrue(new LockerSessionDao().list(f, 1, 5).size() > 0);
    }
}
