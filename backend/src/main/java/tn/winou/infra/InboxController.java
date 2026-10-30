package tn.winou.infra;

import java.time.OffsetDateTime;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.InboxOut;

@RestController
@Tag(name = "notifications")
public class InboxController {

    private final Inbox inbox;

    public InboxController(Inbox inbox) {
        this.inbox = inbox;
    }

    @GetMapping("/me/notifications")
    @Operation(summary = "Notifications you were sent, newest first, and how many are unread",
            description = "title_key and body_key are the push's text keys, filled with their args; body is a chat "
                    + "message shown as is; data says what to open. `before` pages back.")
    public InboxOut list(
            @CurrentUser User user,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime before,
            @RequestParam(defaultValue = "50") @Min(1) @Max(100) int limit) {
        return inbox.list(user.getId(), before, limit);
    }

    @PostMapping("/me/notifications/read")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Marks them all read")
    public void read(@CurrentUser User user) {
        inbox.markAllRead(user.getId());
    }
}
