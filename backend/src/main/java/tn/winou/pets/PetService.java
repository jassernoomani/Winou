package tn.winou.pets;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import tn.winou.common.ApiException;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Pet;
import tn.winou.domain.PetRepository;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.PhotoSource;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.User;
import tn.winou.photos.PhotoService;
import tn.winou.reports.LostReportService;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.LostReportIn;
import tn.winou.web.ApiModels.LostReportOut;
import tn.winou.web.ApiModels.PetIn;
import tn.winou.web.ApiModels.PetLostIn;
import tn.winou.web.ApiModels.PetOut;
import tn.winou.web.ApiModels.PhotoOut;
import tn.winou.web.Views;

/** "My pets": described ahead of time, with photos; marked lost in one step. */
@Service
public class PetService {

    private final PetRepository pets;
    private final PhotoRepository photos;
    private final PhotoService photoService;
    private final LostReportRepository reports;
    private final LostReportService reportService;
    private final Views views;

    public PetService(PetRepository pets, PhotoRepository photos, PhotoService photoService,
            LostReportRepository reports, LostReportService reportService, Views views) {
        this.pets = pets;
        this.photos = photos;
        this.photoService = photoService;
        this.reports = reports;
        this.reportService = reportService;
        this.views = views;
    }

    @Transactional(readOnly = true)
    public List<PetOut> mine(User user) {
        return out(pets.findByOwnerIdOrderByCreatedAt(user.getId()));
    }

    @Transactional
    public PetOut create(PetIn body, User user) {
        if (pets.findByOwnerIdOrderByCreatedAt(user.getId()).size() >= 20) {
            throw ApiException.coded(HttpStatus.CONFLICT, "too_many_pets", "At most 20 pets.");
        }
        Pet pet = new Pet();
        pet.setOwnerId(user.getId());
        apply(pet, body);
        return out(List.of(pets.save(pet))).getFirst();
    }

    /** Null fields are left unchanged. */
    @Transactional
    public PetOut update(UUID id, PetIn body, User user) {
        Pet pet = owned(id, user);
        apply(pet, body);
        return out(List.of(pets.save(pet))).getFirst();
    }

    @Transactional
    public void delete(UUID id, User user) {
        Pet pet = owned(id, user);
        photoService.deleteFilesAfterCommit(photos.findByPetIdInOrderByCreatedAt(List.of(pet.getId())));
        pets.delete(pet); // photos cascade; a lost report made from it stays
    }

    /** All of a user's pets, when their account goes. */
    @Transactional
    public void deleteAll(User user) {
        for (Pet pet : pets.findByOwnerIdOrderByCreatedAt(user.getId())) {
            delete(pet.getId(), user);
        }
    }

    @Transactional
    public PhotoOut addPhoto(UUID id, MultipartFile file, PhotoSource source, User user) {
        return photoService.add(user, PhotoService.Owner.PET, owned(id, user).getId(), file, source);
    }

    /**
     * The pet is missing: a lost report with its name, species, description and microchip, and
     * copies of its photos, which are matched. 409 if it already has an open report.
     */
    @Transactional
    public LostReportOut markLost(UUID id, PetLostIn body, User user) {
        Pet pet = owned(id, user);
        if (openReport(pet.getId()) != null) {
            throw ApiException.coded(HttpStatus.CONFLICT, "already_lost", "This pet already has an open report.");
        }
        List<Photo> petPhotos = photos.findByPetIdInOrderByCreatedAt(List.of(pet.getId()));
        if (petPhotos.isEmpty()) {
            throw ApiException.coded(HttpStatus.UNPROCESSABLE_CONTENT, "no_photos", "Add a photo of the pet first.");
        }
        String description = body.description() != null && !body.description().isBlank() ? body.description()
                : pet.getDescription();
        LostReportOut created = reportService.create(new LostReportIn(pet.getName(), pet.getSpecies(), description,
                body.lastSeen(), body.lastSeenAt(), body.rewardTnd(), pet.getMicrochipped(), body.contactPhone()), user);
        LostReport report = reports.findById(created.id()).orElseThrow();
        report.setPetId(pet.getId());
        reports.save(report);
        for (Photo photo : petPhotos) {
            photoService.copyTo(photo, report.getId(), user);
        }
        return views.report(report, user);
    }

    private void apply(Pet pet, PetIn body) {
        if (body.name() != null) {
            if (body.name().isBlank()) {
                throw ApiException.invalid("The name can't be empty");
            }
            pet.setName(body.name().strip());
        }
        if (body.species() != null) {
            pet.setSpecies(body.species());
        }
        if (body.description() != null) {
            pet.setDescription(body.description().isBlank() ? null : body.description().strip());
        }
        if (body.microchipped() != null) {
            pet.setMicrochipped(body.microchipped());
        }
        if (pet.getName() == null || pet.getSpecies() == null) {
            throw ApiException.invalid("A pet needs a name and a species");
        }
    }

    private Pet owned(UUID id, User user) {
        Pet pet = pets.findById(id).orElseThrow(() -> ApiException.notFound("Pet"));
        CurrentUserResolver.requireOwnerOrAdmin(user, pet.getOwnerId());
        return pet;
    }

    private UUID openReport(UUID petId) {
        return reports.findFirstByPetIdAndStatusOrderByCreatedAtDesc(petId, ReportStatus.OPEN)
                .map(LostReport::getId).orElse(null);
    }

    private List<PetOut> out(List<Pet> list) {
        Map<UUID, List<Photo>> byPet = photos.findByPetIdInOrderByCreatedAt(list.stream().map(Pet::getId).toList())
                .stream().collect(Collectors.groupingBy(Photo::getPetId));
        return list.stream().map(p -> new PetOut(p.getId(), p.getName(), p.getSpecies(), p.getDescription(),
                p.getMicrochipped(), byPet.getOrDefault(p.getId(), List.of()).stream().map(Views::photo).toList(),
                openReport(p.getId()), p.getCreatedAt())).toList();
    }
}
