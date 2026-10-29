package tn.winou.chat;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.ConversationOut;
import tn.winou.web.ApiModels.MessageIn;
import tn.winou.web.ApiModels.MessageOut;

@RestController
@Tag(name = "messages")
public class ChatController {

    private final ChatService chat;

    public ChatController(ChatService chat) {
        this.chat = chat;
    }

    @PostMapping("/matches/{id}/conversation")
    @Operation(summary = "Open the conversation with the finder of a match (owner only); created on first use")
    public ConversationOut start(@PathVariable UUID id, @CurrentUser User user) {
        return chat.start(id, user);
    }

    @GetMapping("/conversations")
    @Operation(summary = "Your conversations, most recent activity first")
    public List<ConversationOut> mine(@CurrentUser User user) {
        return chat.mine(user);
    }

    @GetMapping("/conversations/{id}")
    public ConversationOut get(@PathVariable UUID id, @CurrentUser User user) {
        return chat.get(id, user);
    }

    @GetMapping("/conversations/{id}/messages")
    @Operation(summary = "Messages, oldest first; without `before`, the newest ones, marked read")
    public List<MessageOut> messages(
            @PathVariable UUID id,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime before,
            @RequestParam(defaultValue = "50") @Min(1) @Max(200) int limit,
            @CurrentUser User user) {
        return chat.messages(id, before, limit, user);
    }

    @PostMapping("/conversations/{id}/messages")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Send a message; the other participant gets a push notification")
    public MessageOut send(@PathVariable UUID id, @Valid @RequestBody MessageIn body, @CurrentUser User user) {
        return chat.send(id, body.body(), user);
    }
}
