package tool;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

/** The secret key of LOCKER-01 for the test tools (scripts/set-device-key.ps1 writes it; never hard-code it). */
final class DeviceKey {

    private DeviceKey() {
    }

    /** System property smartlocker.apiKey, else LOCKER-01 in config/device-keys.local.properties, else "". */
    static String locker01() {
        String key = System.getProperty("smartlocker.apiKey");
        if (key != null && !key.trim().isEmpty()) {
            return key.trim();
        }
        File file = new File("config/device-keys.local.properties");   // NetBeans runs from the project folder
        try (FileInputStream in = new FileInputStream(file)) {
            Properties p = new Properties();
            p.load(in);
            if (p.getProperty("LOCKER-01") != null) {
                return p.getProperty("LOCKER-01").trim();
            }
        } catch (IOException e) {
            // no local file: fall through
        }
        System.out.println("No key for LOCKER-01: run scripts/set-device-key.ps1 or pass -Dsmartlocker.apiKey=...");
        return "";
    }
}
