package tn.winou.alerts;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.AlertAreaIn;
import tn.winou.web.ApiModels.AlertAreaOut;

@RestController
@Tag(name = "alerts")
public class AlertAreaController {

    private final AlertAreas areas;

    public AlertAreaController(AlertAreas areas) {
        this.areas = areas;
    }

    @GetMapping("/me/alert-area")
    @Operation(summary = "The area you watch; 204 if none")
    public ResponseEntity<AlertAreaOut> get(@CurrentUser User user) {
        AlertAreaOut area = areas.get(user);
        return area == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(area);
    }

    @PutMapping("/me/alert-area")
    @Operation(summary = "Watch an area: a push when a pet goes missing there (lost) or an animal needs help (help)")
    public AlertAreaOut set(@Valid @RequestBody AlertAreaIn body, @CurrentUser User user) {
        return areas.set(user, body);
    }

    @DeleteMapping("/me/alert-area")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void clear(@CurrentUser User user) {
        areas.clear(user);
    }
}
