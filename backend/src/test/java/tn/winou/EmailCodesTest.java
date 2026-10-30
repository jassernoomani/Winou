package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import tools.jackson.databind.JsonNode;

/** Codes by email: confirming an address, and choosing a new password after forgetting it. */
class EmailCodesTest extends ApiTestBase {

    private String email() {
        return "user-" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
    }

    private JsonNode signUp(String email) {
        return postJson("/auth/register", null, Map.of("email", email, "password", "password123",
                "display_name", "Sami")).json();
    }

    private Response login(String email, String password) {
        return call(post("/auth/login").contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("username", email).param("password", password));
    }

    private Response resetConfirm(String email, String code, String password) {
        return postJson("/auth/password-reset/confirm", null,
                Map.of("email", email, "code", code, "new_password", password));
    }

    private static String code(Response response) {
        return response.json().path("detail").path("code").asString();
    }

    /** Any 6 digits but [code]. */
    private static String wrong(String code) {
        return code.equals("000000") ? "111111" : "000000";
    }

    @Test
    void signingUpEmailsACodeThatConfirmsTheAddress() {
        String email = email();
        String token = signUp(email).path("access_token").asString();
        assertThat(getJson("/me", token).json().path("email_verified").asBoolean()).isFalse();
        assertThat(mailer.sent).hasSize(1);
        assertThat(mailer.sent.getFirst().to()).isEqualTo(email);
        assertThat(mailer.sent.getFirst().subject()).startsWith("Confirm your Winou email");
        String code = mailer.lastCode(email);

        Response wrongCode = postJson("/me/email/verification/confirm", token, Map.of("code", wrong(code)));
        assertThat(wrongCode.status()).isEqualTo(422);
        assertThat(code(wrongCode)).isEqualTo("wrong_code");

        Response confirmed = postJson("/me/email/verification/confirm", token, Map.of("code", code));
        assertThat(confirmed.status()).isEqualTo(200);
        assertThat(confirmed.json().path("email_verified").asBoolean()).isTrue();
        assertThat(code(postJson("/me/email/verification", token, Map.of()))).isEqualTo("already_verified");
    }

    @Test
    void aForgottenPasswordIsReplacedWithACode() {
        String email = email();
        String oldPhone = signUp(email).path("access_token").asString();
        mailer.sent.clear();

        assertThat(postJson("/auth/password-reset", null, Map.of("email", email.toUpperCase())).status())
                .isEqualTo(202);
        assertThat(mailer.sent).hasSize(1);
        assertThat(mailer.sent.getFirst().subject()).startsWith("Your Winou code");
        String code = mailer.lastCode(email);

        assertThat(code(resetConfirm(email, wrong(code), "brand-new-pass"))).isEqualTo("wrong_code");
        Response reset = resetConfirm(email, code, "brand-new-pass");
        assertThat(reset.status()).as(reset.text()).isEqualTo(200);
        String token = reset.json().path("access_token").asString();
        assertThat(getJson("/me", token).json().path("email_verified").asBoolean()).isTrue(); // they read it

        assertThat(login(email, "password123").status()).isEqualTo(401);
        assertThat(login(email, "brand-new-pass").status()).isEqualTo(200);
        assertThat(getJson("/me", oldPhone).status()).isEqualTo(401); // someone else may have known the old one
        assertThat(code(resetConfirm(email, code, "another-pass-1"))).isEqualTo("code_expired"); // used up
    }

    @Test
    void aCodeAllowsFiveTries() {
        String email = email();
        signUp(email);
        postJson("/auth/password-reset", null, Map.of("email", email));
        String code = mailer.lastCode(email);
        for (int i = 0; i < 5; i++) {
            assertThat(code(resetConfirm(email, wrong(code), "brand-new-pass"))).isEqualTo("wrong_code");
        }
        assertThat(code(resetConfirm(email, code, "brand-new-pass"))).isEqualTo("code_expired");

        // A new code works, and the old one doesn't
        postJson("/auth/password-reset", null, Map.of("email", email));
        String fresh = mailer.lastCode(email);
        if (!fresh.equals(code)) {
            assertThat(code(resetConfirm(email, code, "brand-new-pass"))).isEqualTo("wrong_code");
        }
        assertThat(resetConfirm(email, fresh, "brand-new-pass").status()).isEqualTo(200);
    }

    @Test
    void unknownEmailsGetTheSameAnswerAndNoEmail() {
        assertThat(postJson("/auth/password-reset", null, Map.of("email", "nobody@example.com")).status())
                .isEqualTo(202);
        assertThat(mailer.sent).isEmpty();
        assertThat(code(resetConfirm("nobody@example.com", "123456", "brand-new-pass"))).isEqualTo("code_expired");
    }

    @Test
    void atMostThreeCodesAnHour() {
        String email = email();
        String token = signUp(email).path("access_token").asString(); // 1: the sign-up's code
        assertThat(postJson("/me/email/verification", token, Map.of()).status()).isEqualTo(202);
        assertThat(postJson("/me/email/verification", token, Map.of()).status()).isEqualTo(202);
        Response fourth = postJson("/me/email/verification", token, Map.of());
        assertThat(fourth.status()).isEqualTo(429);
        assertThat(code(fourth)).isEqualTo("too_many_codes");
        assertThat(mailer.sent).hasSize(3);

        for (int i = 0; i < 4; i++) { // resets count apart; the 4th says the same and sends nothing
            assertThat(postJson("/auth/password-reset", null, Map.of("email", email)).status()).isEqualTo(202);
        }
        assertThat(mailer.sent).hasSize(6);
    }

    @Test
    void phonesInArabicGetEmailsInArabic() {
        String email = email();
        call(post("/auth/register").contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.ACCEPT_LANGUAGE, "ar-TN,ar;q=0.9")
                .content(body(Map.of("email", email, "password", "password123", "display_name", "سامي"))));
        assertThat(mailer.sent.getFirst().subject()).startsWith("تأكيد بريدك الإلكتروني على Winou: ");
        assertThat(mailer.sent.getFirst().text()).startsWith("مرحبًا سامي،");
        assertThat(mailer.lastCode(email)).hasSize(6);
    }

    @Test
    void phonesInFrenchGetEmailsInFrench() {
        String email = email();
        call(post("/auth/register").contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.ACCEPT_LANGUAGE, "fr-FR,fr;q=0.9")
                .content(body(Map.of("email", email, "password", "password123", "display_name", "Sami"))));
        assertThat(mailer.sent.getFirst().subject()).startsWith("Confirmez votre e-mail Winou");
        assertThat(mailer.sent.getFirst().text()).startsWith("Bonjour Sami,");
    }
}
