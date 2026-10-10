package util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import org.mindrot.jbcrypt.BCrypt;

/** Password hashing (BCrypt) and the SHA-256 used for device API keys. */
public class SecurityUtils {

    /** 60 characters, a new random salt every call, so the same password never gives the same hash. */
    public static String hashPassword(String plain) {
        throw Todo.of("SecurityUtils.hashPassword: BCrypt.hashpw(plain, BCrypt.gensalt(10))");
    }

    /** true when the password matches the stored hash. Never throws. */
    public static boolean checkPassword(String plain, String hash) {
        throw Todo.of("SecurityUtils.checkPassword: null check, BCrypt.checkpw, catch IllegalArgumentException");
    }

    /** Lower-case hex SHA-256, the same text SQL Server gives for HASHBYTES('SHA2_256', varchar). */
    public static String sha256Hex(String text) {
        throw Todo.of("SecurityUtils.sha256Hex: MessageDigest SHA-256 over UTF-8 bytes, then hex");
    }
}
