package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.Map;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import tools.jackson.databind.JsonNode;

/** Staying signed in, signing out, limits on wrong passwords, and managing your own account. */
class AuthSessionsTest extends ApiTestBase {

    private String email() {
        return "user-" + UUID.randomUUID().toString().substring(0, 8) + "@example.com";
    }

    private JsonNode signUp(String email) {
        Response response = postJson("/auth/register", null,
                Map.of("email", email, "password", "password123", "display_name", "Sami"));
        assertThat(response.status()).as(response.text()).isEqualTo(201);
        return response.json();
    }

    private Response login(String email, String password) {
        return call(post("/auth/login").contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("username", email).param("password", password));
    }

    private Response refresh(String refreshToken) {
        return postJson("/auth/refresh", null, Map.of("refresh_token", refreshToken));
    }

    private Response deleteMe(String token, String password) {
        return call(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/me")
                .contentType(MediaType.APPLICATION_JSON).content(body(Map.of("password", password)))
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + token));
    }

    private static String access(JsonNode tokens) {
        return tokens.path("access_token").asString();
    }

    private static String refreshToken(JsonNode tokens) {
        return tokens.path("refresh_token").asString();
    }

    @Test
    void aRefreshTokenGetsANewPairOnce() {
        JsonNode first = signUp(email());
        assertThat(refreshToken(first)).isNotBlank();

        Response renewed = refresh(refreshToken(first));
        assertThat(renewed.status()).isEqualTo(200);
        assertThat(getJson("/me", access(renewed.json())).status()).isEqualTo(200);
        assertThat(refreshToken(renewed.json())).isNotEqualTo(refreshToken(first));

        Response reused = refresh(refreshToken(first));
        assertThat(reused.status()).isEqualTo(401);
        assertThat(reused.json().path("detail").path("code").asString()).isEqualTo("session_expired");
        assertThat(refresh(refreshToken(renewed.json())).status()).isEqualTo(200);
        assertThat(refresh("made-up").status()).isEqualTo(401);
    }

    @Test
    void signingOutEndsThatSessionOnly() {
        String email = email();
        JsonNode phone = signUp(email);
        JsonNode tablet = login(email, "password123").json();

        assertThat(postJson("/auth/logout", null, Map.of("refresh_token", refreshToken(phone))).status())
                .isEqualTo(204);
        assertThat(refresh(refreshToken(phone)).status()).isEqualTo(401);
        assertThat(refresh(refreshToken(tablet)).status()).isEqualTo(200);
    }

    @Test
    void wrongPasswordsAreLimitedPerEmail() {
        String email = email();
        signUp(email);
        for (int i = 0; i < 5; i++) {
            assertThat(login(email, "wrong-password").status()).isEqualTo(401);
        }
        Response blocked = login(email, "password123"); // even the right one, for a while
        assertThat(blocked.status()).isEqualTo(429);
        assertThat(blocked.json().path("detail").path("code").asString()).isEqualTo("too_many_attempts");

        String other = email();
        signUp(other);
        assertThat(login(other, "password123").status()).isEqualTo(200);
    }

    @Test
    void aSuccessfulSignInForgetsEarlierMistakes() {
        String email = email();
        signUp(email);
        for (int i = 0; i < 4; i++) {
            login(email, "wrong-password");
        }
        assertThat(login(email, "password123").status()).isEqualTo(200);
        for (int i = 0; i < 4; i++) {
            assertThat(login(email, "wrong-password").status()).isEqualTo(401);
        }
    }

    @Test
    void aNewPasswordSignsOutEveryOtherPhone() {
        String email = email();
        JsonNode phone = signUp(email);
        JsonNode tablet = login(email, "password123").json();

        Response wrong = postJson("/me/password", access(phone),
                Map.of("current_password", "nope-nope", "new_password", "new-password-1"));
        assertThat(wrong.status()).isEqualTo(403);
        assertThat(wrong.json().path("detail").path("code").asString()).isEqualTo("wrong_password");
        assertThat(postJson("/me/password", access(phone),
                Map.of("current_password", "password123", "new_password", "short")).status()).isEqualTo(422);

        Response changed = postJson("/me/password", access(phone),
                Map.of("current_password", "password123", "new_password", "new-password-1"));
        assertThat(changed.status()).isEqualTo(200);
        assertThat(getJson("/me", access(changed.json())).status()).isEqualTo(200);
        assertThat(getJson("/me", access(tablet)).status()).isEqualTo(401);
        assertThat(refresh(refreshToken(tablet)).status()).isEqualTo(401);
        assertThat(login(email, "password123").status()).isEqualTo(401);
        assertThat(login(email, "new-password-1").status()).isEqualTo(200);
    }

    @Test
    void signingOutEverywhereEndsEverySession() {
        String email = email();
        JsonNode phone = signUp(email);
        JsonNode tablet = login(email, "password123").json();

        assertThat(postJson("/me/sign-out-everywhere", access(phone), Map.of()).status()).isEqualTo(204);
        assertThat(getJson("/me", access(phone)).status()).isEqualTo(401);
        assertThat(getJson("/me", access(tablet)).status()).isEqualTo(401);
        assertThat(refresh(refreshToken(phone)).status()).isEqualTo(401);
        assertThat(refresh(refreshToken(tablet)).status()).isEqualTo(401);
        assertThat(login(email, "password123").status()).isEqualTo(200); // signing in again works
    }

    @Test
    void deletingTheAccountRemovesEverythingPosted() {
        String email = email();
        String token = access(signUp(email));
        String neighbour = register("neighbour");
        String report = lostReport(token).path("id").asString();
        sighting(token, RED);
        work();
        assertThat(storage.objects).isNotEmpty();

        assertThat(deleteMe(token, "wrong-password").status()).isEqualTo(403);
        assertThat(deleteMe(token, "password123").status()).isEqualTo(204);

        assertThat(getJson("/lost-reports/" + report, neighbour).status()).isEqualTo(404);
        assertThat(storage.objects).isEmpty();
        assertThat(login(email, "password123").status()).isEqualTo(401);
        assertThat(getJson("/me", token).status()).isEqualTo(401);
        // The email is free again
        assertThat(postJson("/auth/register", null,
                Map.of("email", email, "password", "password123", "display_name", "Sami")).status()).isEqualTo(201);
    }

    @Test
    void aBannedUserCantRenewTheirSession() {
        String admin = postJson("/auth/register", null, Map.of("email", ADMIN_EMAIL, "password", "password123",
                "display_name", "Admin")).json().path("access_token").asString();
        JsonNode user = signUp(email());
        String id = getJson("/me", access(user)).json().path("id").asString();
        postJson("/admin/users/" + id + "/ban", admin, Map.of("days", 1));

        Response renewed = refresh(refreshToken(user));
        assertThat(renewed.status()).isEqualTo(403);
        assertThat(renewed.json().path("detail").path("code").asString()).isEqualTo("banned");
    }

    @Test
    void theNameCantBeBlank() {
        String token = access(signUp(email()));
        assertThat(patchJson("/me", token, Map.of("display_name", "   ")).status()).isEqualTo(422);
        assertThat(patchJson("/me", token, Map.of("display_name", " Sami B ")).json().path("display_name").asString())
                .isEqualTo("Sami B");
    }
}
