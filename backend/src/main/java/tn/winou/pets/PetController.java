package tn.winou.pets;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import tn.winou.domain.PhotoSource;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.LostReportOut;
import tn.winou.web.ApiModels.PetIn;
import tn.winou.web.ApiModels.PetLostIn;
import tn.winou.web.ApiModels.PetOut;
import tn.winou.web.ApiModels.PhotoOut;

@RestController
@Tag(name = "pets")
public class PetController {

    private final PetService pets;

    public PetController(PetService pets) {
        this.pets = pets;
    }

    @GetMapping("/me/pets")
    @Operation(summary = "Your pets, with their photos and the open lost report of each, if any")
    public List<PetOut> mine(@CurrentUser User user) {
        return pets.mine(user);
    }

    @PostMapping("/me/pets")
    @ResponseStatus(HttpStatus.CREATED)
    public PetOut create(@Valid @RequestBody PetIn body, @CurrentUser User user) {
        return pets.create(body, user);
    }

    @PatchMapping("/pets/{id}")
    @Operation(summary = "Null fields are left unchanged")
    public PetOut update(@PathVariable UUID id, @Valid @RequestBody PetIn body, @CurrentUser User user) {
        return pets.update(id, body, user);
    }

    @DeleteMapping("/pets/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID id, @CurrentUser User user) {
        pets.delete(id, user);
    }

    @PostMapping(value = "/pets/{id}/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "A photo of the pet (5 at most). Kept, not matched, until the pet is marked lost")
    public PhotoOut addPhoto(@PathVariable UUID id, @RequestPart MultipartFile file,
            @RequestParam(required = false) PhotoSource source, @CurrentUser User user) {
        return pets.addPhoto(id, file, source, user);
    }

    @PostMapping("/pets/{id}/lost")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "The pet is missing: a lost report from its profile, its photos copied and matched",
            description = "409 \"already_lost\" if it has an open report; 422 \"no_photos\" without a photo.")
    public LostReportOut markLost(@PathVariable UUID id, @Valid @RequestBody PetLostIn body, @CurrentUser User user) {
        return pets.markLost(id, body, user);
    }
}
