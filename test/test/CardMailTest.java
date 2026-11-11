package test;

import java.util.HashMap;
import java.util.Map;
import org.testng.Assert;
import org.testng.annotations.Test;
import service.AuthText;
import service.CardMail;

/** The link secret of the card e-mail, and the texts the box prints for the new replies. */
public class CardMailTest {

    @Test
    public void tokenIs256RandomBitsInHex() {
        String a = CardMail.newToken();
        String b = CardMail.newToken();
        Assert.assertTrue(a.matches("[0-9a-f]{64}"), a);
        Assert.assertNotEquals(a, b);
    }

    @Test
    public void hashIsSha256OfTheToken() {
        Assert.assertEquals(CardMail.hash("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    }

    @Test
    public void everyPhaseSaysWhatTheScanDoes() {
        Assert.assertTrue(CardMail.action("PICKUP").contains("trả tủ"));
        Assert.assertTrue(CardMail.action("ACCESS").contains("tiếp tục"));
        Assert.assertTrue(CardMail.action("CHECK_IN").contains("cất đồ"));
    }

    private static void assertFitsOled(String message) {
        String[] lines = message.split("\n");
        Assert.assertTrue(lines.length <= 2, message);
        for (String line : lines) {
            Assert.assertTrue(line.length() <= 16, line);
            Assert.assertTrue(line.matches("\\p{ASCII}*"), line);
        }
    }

    @Test
    public void newBoxMessagesFitTheOled() {
        Map<String, Object> row = new HashMap<>();
        row.put("result", "CONFIRM_EMAIL");
        assertFitsOled(AuthText.oled(row));
        row.put("result", "DENY");
        row.put("reason", "WRONG_PLACE");
        row.put("right_bank", "CANT-B");
        Assert.assertEquals(AuthText.oled(row), "Sai cho! Tu o\nCANT-B");
        assertFitsOled(AuthText.oled(row));
    }
}
