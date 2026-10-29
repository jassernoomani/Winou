package tn.winou.matching;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Match;
import tn.winou.domain.MatchRepository;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.security.CurrentUser;
import tn.winou.web.ApiModels.MatchOut;
import tn.winou.web.ApiModels.SightingOut;
import tn.winou.web.Views;

@RestController
@Tag(name = "matches")
public class MatchController {

    private final MatchRepository matches;
    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final Views views;

    public MatchController(MatchRepository matches, LostReportRepository reports, SightingRepository sightings,
            Views views) {
        this.matches = matches;
        this.reports = reports;
        this.sightings = sightings;
        this.views = views;
    }

    @GetMapping("/me/matches")
    @Transactional(readOnly = true)
    @Operation(summary = "Possible sightings of your lost pets, best score first")
    public List<MatchOut> mine(@CurrentUser User user) {
        List<Match> found = matches.findForOwner(user.getId());
        Map<UUID, LostReport> reportsById = reports.findAllById(found.stream().map(Match::getLostReportId).toList())
                .stream().collect(Collectors.toMap(LostReport::getId, Function.identity()));
        Map<UUID, SightingOut> sightingsById = views.sightings(
                        sightings.findAllById(found.stream().map(Match::getSightingId).distinct().toList()), user)
                .stream().collect(Collectors.toMap(SightingOut::id, Function.identity()));
        return found.stream().map(m -> new MatchOut(m.getId(), m.getLostReportId(),
                reportsById.get(m.getLostReportId()).getName(), m.getScore(), m.getStatus(),
                sightingsById.get(m.getSightingId()), Views.imageUrl(m.getLostPhotoId()),
                Views.imageUrl(m.getSightingPhotoId()), m.getCreatedAt())).toList();
    }
}
