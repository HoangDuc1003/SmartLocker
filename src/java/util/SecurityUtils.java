package util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import org.mindrot.jbcrypt.BCrypt;

/** Password hashing (BCrypt) and the SHA-256 used for device API keys. */
public class SecurityUtils {

    /** 60 characters, a new random salt every call, so the same password never gives the same hash. */
    public static String hashPassword(String plain) {
        return BCrypt.hashpw(plain, BCrypt.gensalt(10));
    }

    /** true when the password matches the stored hash. Never throws. */
    public static boolean checkPassword(String plain, String hash) {
        if (plain == null || hash == null) {
            return false;
        }
        try {
            return BCrypt.checkpw(plain, hash);
        } catch (IllegalArgumentException e) {
            return false;   // the stored value is not a BCrypt hash, like the 'system' account
        }
    }

    /** Lower-case hex SHA-256, the same text SQL Server gives for HASHBYTES('SHA2_256', varchar). */
    public static String sha256Hex(String text) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
