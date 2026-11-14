package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertTrue;

import java.util.HashMap;
import java.util.Map;
import org.testng.annotations.Test;
import service.AuthText;

/**
 * v6, open many times: the texts of CHOOSE and of an UNLOCK with phase ACCESS. No database: AuthText only reads a row.
 * Every OLED text must fit the LCD 1602 of the box: ASCII, 2 lines of 16 at most.
 */
public class AuthTextTest {

    private static Map<String, Object> row(String result, String phase) {
        Map<String, Object> row = new HashMap<>();
        row.put("result", result);
        row.put("phase", phase);
        row.put("slot_code", "A01");
        return row;
    }

    private static void assertFitsLcd(String text) {
        assertTrue(text.matches("[\\x20-\\x7E\\n]*"), "ASCII only: " + text);
        String[] lines = text.split("\n");
        assertTrue(lines.length <= 2, "2 lines at most: " + text);
        for (String line : lines) {
            assertTrue(line.length() <= 16, "16 characters at most: " + line);
        }
    }

    @Test
    public void chooseAsksForAOrB() {
        String oled = AuthText.oled(row("CHOOSE", null));
        assertEquals(oled, "A: Open * cancel\nB: Checkout A01");
        assertFitsLcd(oled);
        assertTrue(AuthText.phone(row("CHOOSE", null)).contains("Check out"));
    }

    @Test
    public void accessKeepsTheRental() {
        String oled = AuthText.oled(row("UNLOCK", "ACCESS"));
        assertEquals(oled, "Open the door\nSlot A01");
        assertFitsLcd(oled);
        assertTrue(AuthText.phone(row("UNLOCK", "ACCESS")).contains("is still yours"));
    }

    @Test
    public void checkInAndPickupUnchanged() {
        assertEquals(AuthText.oled(row("UNLOCK", "CHECK_IN")), "Store your items\nSlot A01");
        assertEquals(AuthText.oled(row("UNLOCK", "PICKUP")), "Take your items\nSlot A01");
        assertTrue(AuthText.phone(row("UNLOCK", "PICKUP")).contains("the booking will end"));
    }
}
