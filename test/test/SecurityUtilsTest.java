package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertFalse;
import static org.testng.Assert.assertNotEquals;
import static org.testng.Assert.assertTrue;

import org.testng.annotations.Test;
import util.SecurityUtils;

/** Pure Java, no database. */
public class SecurityUtilsTest {

    @Test
    public void hashIsSixtyCharactersAndMatchesItsPassword() {
        String hash = SecurityUtils.hashPassword("123456");
        assertEquals(hash.length(), 60);
        assertTrue(SecurityUtils.checkPassword("123456", hash));
    }

    @Test
    public void wrongPasswordIsRejected() {
        assertFalse(SecurityUtils.checkPassword("654321", SecurityUtils.hashPassword("123456")));
    }

    @Test
    public void twoHashesOfOnePasswordDiffer() {
        assertNotEquals(SecurityUtils.hashPassword("123456"), SecurityUtils.hashPassword("123456"));
    }

    @Test
    public void aStoredValueThatIsNotBcryptNeverLogsIn() {
        // the 'system' account has 60 x characters as its hash
        assertFalse(SecurityUtils.checkPassword("123456", "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"));
        assertFalse(SecurityUtils.checkPassword(null, SecurityUtils.hashPassword("123456")));
    }

    @Test
    public void sha256MatchesTheHashSqlServerStoresForTheDemoKey() {
        assertEquals(SecurityUtils.sha256Hex("device-1-api-key"),
                "73fb4e98f6db0f8a286c82e03e54764c4d8cd556fcfd858c0f6edf61cdaec849");
    }
}
