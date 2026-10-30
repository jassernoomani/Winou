package tn.winou.moderation;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.ContentReportIn;
import tn.winou.web.ApiModels.ContentReportOut;
import tn.winou.web.ApiModels.HiddenItemOut;
import tn.winou.web.ApiModels.ReportTarget;

@RestController
@Tag(name = "moderation")
public class ModerationController {

    private final ModerationService moderation;

    public ModerationController(ModerationService moderation) {
        this.moderation = moderation;
    }

    @PostMapping("/reports")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Report a lost report, sighting or message",
            description = "Once HIDE_AFTER_REPORTS different people reported it, it is hidden from everyone but its "
                    + "author until an admin reviews it; a message, once its recipient reports it. Reporting the same "
                    + "thing twice changes nothing.")
    public ContentReportOut report(@Valid @RequestBody ContentReportIn body, @CurrentUser User user) {
        return moderation.report(body, user);
    }

    @GetMapping("/admin/reported")
    @Operation(summary = "Content people reported that is still shown, the most reported first (admins only)")
    public List<HiddenItemOut> reported(@CurrentUser User user) {
        return moderation.reported(user);
    }

    @PostMapping("/admin/content/{type}/{id}/hide")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Hide it now, from everyone but its author, until an admin restores it")
    public void hide(@PathVariable ReportTarget type, @PathVariable UUID id, @CurrentUser User user) {
        moderation.hide(type, id, user);
    }

    @PostMapping("/admin/content/{type}/{id}/dismiss")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Forget its reports: they were wrong. It stays shown.")
    public void dismiss(@PathVariable ReportTarget type, @PathVariable UUID id, @CurrentUser User user) {
        moderation.dismiss(type, id, user);
    }

    @DeleteMapping("/admin/content/{type}/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Delete any lost report, sighting or message, reported or not")
    public void deleteContent(@PathVariable ReportTarget type, @PathVariable UUID id, @CurrentUser User user) {
        moderation.delete(type, id, user);
    }

    @GetMapping("/admin/hidden")
    @Operation(summary = "Hidden content with its reports, most recently hidden first (admins only)")
    public List<HiddenItemOut> hidden(@CurrentUser User user) {
        return moderation.hidden(user);
    }

    @PostMapping("/admin/hidden/{type}/{id}/restore")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Show it again; its reports are cleared")
    public void restore(@PathVariable ReportTarget type, @PathVariable UUID id, @CurrentUser User user) {
        moderation.restore(type, id, user);
    }

    @DeleteMapping("/admin/hidden/{type}/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable ReportTarget type, @PathVariable UUID id, @CurrentUser User user) {
        moderation.delete(type, id, user);
    }
}
