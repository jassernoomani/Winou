package tn.winou.security;

import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.stereotype.Component;

/** Argon2id, with the parameters argon2-cffi used in the Python API, so existing hashes verify. */
@Component
public class Passwords {

    private final Argon2PasswordEncoder encoder = new Argon2PasswordEncoder(16, 32, 4, 65536, 3);
    // Checked when the email is unknown, so login takes the same time either way
    private final String dummyHash = encoder.encode("not-a-real-password");

    public String hash(String password) {
        return encoder.encode(password);
    }

    /** hash may be null (unknown user): the check still runs, and fails. */
    public boolean verify(String hash, String password) {
        boolean matches = encoder.matches(password, hash != null ? hash : dummyHash);
        return matches && hash != null;
    }
}
