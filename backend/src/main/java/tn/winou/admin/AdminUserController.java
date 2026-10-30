package tn.winou.admin;

import java.util.List;
import java.util.UUID;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.AdminUserDetailOut;
import tn.winou.web.ApiModels.AdminUserOut;
import tn.winou.web.ApiModels.BanIn;

@RestController
@Tag(name = "admin")
public class AdminUserController {

    private final AdminUserService service;

    public AdminUserController(AdminUserService service) {
        this.service = service;
    }

    @GetMapping("/admin/users")
    @Operation(summary = "Accounts, newest first (admins only). Fewer than `limit` items means the last page.",
            description = "q matches the name or the email; banned=true lists only accounts banned now.")
    public List<AdminUserOut> search(
            @CurrentUser User user,
            @RequestParam(defaultValue = "") @Size(max = 100) String q,
            @RequestParam(defaultValue = "false") boolean banned,
            @RequestParam(defaultValue = "30") @Min(1) @Max(100) int limit,
            @RequestParam(defaultValue = "0") @Min(0) int offset) {
        return service.search(q, banned, limit, offset, user);
    }

    @GetMapping("/admin/users/{id}")
    @Operation(summary = "An account with everything they posted, hidden content included, and its admin history")
    public AdminUserDetailOut detail(@PathVariable UUID id, @CurrentUser User user) {
        return service.detail(id, user);
    }

    @PostMapping("/admin/users/{id}/ban")
    @Operation(summary = "Ban for `days`, or for good without it",
            description = "Takes effect at once: their requests are refused (403, code \"banned\"), they can't sign "
                    + "in, and their lost reports and sightings are hidden from others until the ban ends. "
                    + "Admins can't be banned.")
    public AdminUserOut ban(@PathVariable UUID id, @Valid @RequestBody BanIn body, @CurrentUser User user) {
        return service.ban(id, body, user);
    }

    @PostMapping("/admin/users/{id}/unban")
    public AdminUserOut unban(@PathVariable UUID id, @CurrentUser User user) {
        return service.unban(id, user);
    }

    @DeleteMapping("/admin/users/{id}/association")
    @Operation(summary = "Take back association status: no more badge or injured-animal alerts. They can apply again.")
    public AdminUserOut revokeAssociation(@PathVariable UUID id, @CurrentUser User user) {
        return service.revokeAssociation(id, user);
    }
}
