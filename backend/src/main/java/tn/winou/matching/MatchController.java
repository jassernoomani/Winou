package tn.winou.matching;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import tn.winou.common.ApiException;
import tn.winou.domain.Conversation;
import tn.winou.domain.ConversationRepository;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.MatchStatus;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.infra.Notifications;
import tn.winou.security.CurrentUser;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.MatchOut;
import tn.winou.web.ApiModels.MatchUpdate;
import tn.winou.web.ApiModels.SightingOut;
import tn.winou.web.Views;

@RestController
@Tag(name = "matches")
public class MatchController {

    private final MatchRepository matches;
    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final ConversationRepository conversations;
    private final Views views;
    private final Notifications notifications;
    private final PhotoRepository photos;

    public MatchController(MatchRepository matches, LostReportRepository reports, SightingRepository sightings,
            ConversationRepository conversations, Views views, Notifications notifications, PhotoRepository photos) {
        this.photos = photos;
        this.matches = matches;
        this.reports = reports;
        this.sightings = sightings;
        this.conversations = conversations;
        this.views = views;
        this.notifications = notifications;
    }

    @GetMapping("/me/matches")
    @Transactional(readOnly = true)
    @Operation(summary = "Possible sightings of your lost pets, best score first",
            description = "Rejected matches are left out; for closed cases, only the confirmed ones are listed.")
    public List<MatchOut> mine(@CurrentUser User user) {
        return out(matches.findForOwner(user.getId()), user);
    }

    @PatchMapping("/matches/{id}")
    @Transactional
    @Operation(summary = "Confirm (\"that's my pet\") or reject a match; PENDING undoes a rejection",
            description = "Confirming tells the finder. It does not close the case: mark the lost report FOUND "
                    + "once the pet is back.")
    public MatchOut update(@PathVariable UUID id, @Valid @RequestBody MatchUpdate body, @CurrentUser User user) {
        Match match = matches.findById(id).orElseThrow(() -> ApiException.notFound("Match"));
        LostReport report = reports.findById(match.getLostReportId()).orElseThrow();
        CurrentUserResolver.requireOwnerOrAdmin(user, report.getOwnerId());
        boolean newlyConfirmed = body.status() == MatchStatus.CONFIRMED && match.getStatus() != MatchStatus.CONFIRMED;
        match.setStatus(body.status());
        matches.save(match);
        if (newlyConfirmed) {
            notifications.send(n -> n.matchConfirmed(match));
        }
        return out(List.of(match), user).getFirst();
    }

    private List<MatchOut> out(List<Match> found, User user) {
        Map<UUID, LostReport> reportsById = reports.findAllById(found.stream().map(Match::getLostReportId).toList())
                .stream().collect(Collectors.toMap(LostReport::getId, Function.identity()));
        Map<UUID, SightingOut> sightingsById = views.sightings(
                        sightings.findAllById(found.stream().map(Match::getSightingId).distinct().toList()), user)
                .stream().collect(Collectors.toMap(SightingOut::id, Function.identity()));
        Map<UUID, UUID> conversationByMatch = conversations.findByMatchIdIn(found.stream().map(Match::getId).toList())
                .stream().collect(Collectors.toMap(Conversation::getMatchId, Conversation::getId));
        // A finder's match has no matched photos until the model scores it: show the first ones
        Map<UUID, UUID> firstLostPhoto = new java.util.HashMap<>();
        photos.findByLostReportIdInOrderByCreatedAt(reportsById.keySet().stream().toList())
                .forEach(p -> firstLostPhoto.putIfAbsent(p.getLostReportId(), p.getId()));
        return found.stream().map(m -> {
            LostReport report = reportsById.get(m.getLostReportId());
            SightingOut sighting = sightingsById.get(m.getSightingId());
            String lostPhoto = Views.imageUrl(m.getLostPhotoId() != null ? m.getLostPhotoId()
                    : firstLostPhoto.get(report.getId()));
            String sightingPhoto = m.getSightingPhotoId() != null ? Views.imageUrl(m.getSightingPhotoId())
                    : sighting.photos().isEmpty() ? null : sighting.photos().getFirst().url();
            return new MatchOut(m.getId(), m.getLostReportId(), report.getName(), m.getScore(), m.getSource(),
                    m.getStatus(), sighting, lostPhoto, sightingPhoto, report.getStatus(),
                    conversationByMatch.get(m.getId()), m.getCreatedAt());
        }).toList();
    }
}
