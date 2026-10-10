package test;

import static org.testng.Assert.assertEquals;
import static org.testng.Assert.assertTrue;

import org.testng.annotations.Test;
import util.SecurityUtils;

/**
 * SKELETON. Explained in docs/HUONG_DAN_TUNG_FILE.md, section "test/SecurityUtilsTest.java".
 * Pure Java, no database.
 */
public class SecurityUtilsTest {

    @Test
    public void hashIsSixtyCharactersAndMatchesItsPassword() {
        String hash = SecurityUtils.hashPassword("123456");
        assertEquals(hash.length(), 60);
        assertTrue(SecurityUtils.checkPassword("123456", hash));
    }

    // TODO wrongPasswordIsRejected
    // TODO twoHashesOfOnePasswordDiffer                    (a new salt every time)
    // TODO aStoredValueThatIsNotBcryptNeverLogsIn          (60 x characters like the 'system' account, and a null password)
    // TODO sha256MatchesTheHashSqlServerStoresForTheDemoKey (SecurityUtils.sha256Hex("device-1-api-key") equals the value in Device.api_key_hash)
}
