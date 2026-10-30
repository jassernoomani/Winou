package tn.winou.auth;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.DeleteAccountIn;
import tn.winou.web.ApiModels.PasswordChangeIn;
import tn.winou.web.ApiModels.TokenOut;

@RestController
@Tag(name = "auth")
public class AccountController {

    private final AccountService accounts;

    public AccountController(AccountService accounts) {
        this.accounts = accounts;
    }

    @PostMapping("/me/password")
    @Operation(summary = "Change the password; signs out every other phone and returns a new session")
    public TokenOut changePassword(@Valid @RequestBody PasswordChangeIn body, @CurrentUser User user) {
        return accounts.changePassword(body, user);
    }

    @PostMapping("/me/sign-out-everywhere")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Signs out every phone, this one included")
    public void signOutEverywhere(@CurrentUser User user) {
        accounts.signOutEverywhere(user);
    }

    @DeleteMapping("/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete the account and everything posted with it, for good (password required)")
    public void delete(@Valid @RequestBody DeleteAccountIn body, @CurrentUser User user) {
        accounts.delete(body, user);
    }
}
