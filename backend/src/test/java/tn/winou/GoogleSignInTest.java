package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import tools.jackson.databind.JsonNode;

/** "Continue with Google". The fake Google trusts tokens written "sub|email|email_verified|name". */
class GoogleSignInTest extends ApiTestBase {

    private Response google(String idToken) {
        return postJson("/auth/google", null, Map.of("id_token", idToken));
    }

    private Response login(String email, String password) {
        return call(post("/auth/login").contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("username", email).param("password", password));
    }

    private JsonNode me(Response signedIn) {
        return getJson("/me", signedIn.json().path("access_token").asString()).json();
    }

    @Test
    void aNewGoogleUserGetsAnAccountWithoutPassword() {
        Response signedIn = google("g-1|Leila.B@gmail.com|true|Leila Ben Ali");
        assertThat(signedIn.status()).as(signedIn.text()).isEqualTo(200);
        assertThat(signedIn.json().path("refresh_token").asString()).isNotBlank();

        JsonNode me = me(signedIn);
        assertThat(me.path("email").asString()).isEqualTo("leila.b@gmail.com");
        assertThat(me.path("display_name").asString()).isEqualTo("Leila Ben Ali");
        assertThat(me.path("has_password").asBoolean()).isFalse();
        assertThat(me.path("email_verified").asBoolean()).isTrue();
        assertThat(me.path("google").asBoolean()).isTrue();

        // The next time, the same account
        assertThat(me(google("g-1|leila.b@gmail.com|true|Leila")).path("id")).isEqualTo(me.path("id"));
        // No password to guess
        assertThat(login("leila.b@gmail.com", "").status()).isEqualTo(401);
    }

    @Test
    void googleSignsIntoTheAccountWithThatVerifiedEmail() {
        String token = register("sami");
        String email = getJson("/me", token).json().path("email").asString();
        jdbc.sql("UPDATE users SET email_verified_at = now() WHERE email = :email").param("email", email).update();

        JsonNode me = me(google("g-2|" + email + "|true|Sami"));
        assertThat(me.path("email").asString()).isEqualTo(email);
        assertThat(me.path("has_password").asBoolean()).isTrue();
        assertThat(me.path("google").asBoolean()).isTrue();
        assertThat(getJson("/me", token).status()).isEqualTo(200); // their other phones stay signed in
        assertThat(login(email, "password123").status()).isEqualTo(200);
    }

    @Test
    void googleTakesAnUnverifiedEmailBackFromWhoeverRegisteredIt() {
        String squatter = register("squatter"); // never proved the address was theirs
        String email = getJson("/me", squatter).json().path("email").asString();

        JsonNode me = me(google("g-3|" + email + "|true|Owner"));
        assertThat(me.path("has_password").asBoolean()).isFalse();
        assertThat(login(email, "password123").status()).isEqualTo(401);
        assertThat(getJson("/me", squatter).status()).isEqualTo(401);
    }

    @Test
    void googleAccountsWithoutAVerifiedEmailAreRefused() {
        Response refused = google("g-4|someone@gmail.com|false|Someone");
        assertThat(refused.status()).isEqualTo(422);
        assertThat(refused.json().path("detail").path("code").asString()).isEqualTo("google_no_email");
        assertThat(google("garbage").status()).isEqualTo(401);
    }

    @Test
    void aGoogleAccountSetsAPasswordAndDeletesWithoutOne() {
        String token = google("g-5|nour@gmail.com|true|Nour").json().path("access_token").asString();

        Map<String, Object> setPassword = new HashMap<>();
        setPassword.put("current_password", null);
        setPassword.put("new_password", "first-password");
        Response set = postJson("/me/password", token, setPassword);
        assertThat(set.status()).as(set.text()).isEqualTo(200);
        assertThat(login("nour@gmail.com", "first-password").status()).isEqualTo(200);

        String other = google("g-6|amel@gmail.com|true|Amel").json().path("access_token").asString();
        Response deleted = call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/me")
                .contentType(MediaType.APPLICATION_JSON).content("{}")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + other));
        assertThat(deleted.status()).isEqualTo(204);
    }

    @Test
    void aBannedGoogleUserIsRefused() {
        String admin = postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
        String id = me(google("g-7|karim@gmail.com|true|Karim")).path("id").asString();
        postJson("/admin/users/" + id + "/ban", admin, Map.of("days", 7));

        Response refused = google("g-7|karim@gmail.com|true|Karim");
        assertThat(refused.status()).isEqualTo(403);
        assertThat(refused.json().path("detail").path("code").asString()).isEqualTo("banned");
    }
}
