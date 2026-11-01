package jp.fonix;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;

public final class PinHash {
    private static final int ITERATIONS = 120000;
    public static String create(String pin) throws Exception {
        if (!pin.matches("[0-9]{4,8}")) throw new IllegalArgumentException("Invalid PIN length");
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        return Base64.getEncoder().encodeToString(salt) + ":" +
            Base64.getEncoder().encodeToString(derive(pin, salt));
    }
    public static boolean verify(String pin, String stored) throws Exception {
        if (!pin.matches("[0-9]{4,8}")) return false;
        String[] parts = stored.split(":");
        if (parts.length != 2) return false;
        return MessageDigest.isEqual(derive(pin, Base64.getDecoder().decode(parts[0])),
            Base64.getDecoder().decode(parts[1]));
    }
    private static byte[] derive(String pin, byte[] salt) throws Exception {
        PBEKeySpec spec = new PBEKeySpec(pin.toCharArray(),salt,ITERATIONS,256);
        try { return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded(); }
        finally { spec.clearPassword(); }
    }
}
