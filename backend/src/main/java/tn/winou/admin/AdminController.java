package tn.winou.admin;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.AdminActionOut;
import tn.winou.web.ApiModels.AdminStatsOut;
import tn.winou.web.ApiModels.AdminSummaryOut;

@RestController
@Tag(name = "admin")
public class AdminController {

    private final AdminStatsService service;

    public AdminController(AdminStatsService service) {
        this.service = service;
    }

    @GetMapping("/admin/summary")
    @Operation(summary = "How much waits for an admin: reported, association requests, hidden (admins only)")
    public AdminSummaryOut summary(@CurrentUser User user) {
        return service.summary(user);
    }

    @GetMapping("/admin/stats")
    @Operation(summary = "Totals, and lost reports, sightings and reunions per week for the last 12 weeks")
    public AdminStatsOut stats(@CurrentUser User user) {
        return service.stats(user);
    }

    @GetMapping("/admin/actions")
    @Operation(summary = "What admins did, most recent first. Fewer than `limit` items means the last page.")
    public List<AdminActionOut> actions(
            @CurrentUser User user,
            @RequestParam(defaultValue = "50") @Min(1) @Max(100) int limit,
            @RequestParam(defaultValue = "0") @Min(0) int offset) {
        return service.actions(limit, offset, user);
    }
}
