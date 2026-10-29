package tn.winou.associations;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
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
import tn.winou.web.ApiModels.AssociationRequestIn;
import tn.winou.web.ApiModels.AssociationRequestOut;

@RestController
@Tag(name = "associations")
public class AssociationController {

    private final AssociationService associations;

    public AssociationController(AssociationService associations) {
        this.associations = associations;
    }

    @PostMapping("/me/association-request")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Ask to be shown as an association; an admin reviews it",
            description = "409 request_pending while one is being reviewed, already_association once approved.")
    public AssociationRequestOut request(@Valid @RequestBody AssociationRequestIn body, @CurrentUser User user) {
        return associations.request(body, user);
    }

    @GetMapping("/me/association-request")
    @Operation(summary = "Your latest request; 204 if you never sent one")
    public ResponseEntity<AssociationRequestOut> mine(@CurrentUser User user) {
        AssociationRequestOut mine = associations.mine(user);
        return mine == null ? ResponseEntity.noContent().build() : ResponseEntity.ok(mine);
    }

    @GetMapping("/admin/association-requests")
    @Operation(summary = "Requests waiting for a decision, oldest first (admins only)")
    public List<AssociationRequestOut> pending(@CurrentUser User user) {
        return associations.pending(user);
    }

    @PostMapping("/admin/association-requests/{id}/approve")
    public AssociationRequestOut approve(@PathVariable UUID id, @CurrentUser User user) {
        return associations.decide(id, true, user);
    }

    @PostMapping("/admin/association-requests/{id}/reject")
    public AssociationRequestOut reject(@PathVariable UUID id, @CurrentUser User user) {
        return associations.decide(id, false, user);
    }
}
