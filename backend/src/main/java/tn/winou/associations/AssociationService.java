package tn.winou.associations;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.admin.AdminLog;
import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.AssociationRequest;
import tn.winou.domain.AssociationRequestRepository;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.RequestStatus;
import tn.winou.domain.Role;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.infra.Notifications;
import tn.winou.security.Admins;
import tn.winou.web.ApiModels.AdminAction;
import tn.winou.web.ApiModels.AssociationRequestIn;
import tn.winou.web.ApiModels.AssociationRequestOut;
import tn.winou.web.ApiModels.Location;

/**
 * Users ask to be shown as an association; an admin checks the contact they gave and approves or
 * rejects. Approved associations get a badge and alerts about injured animals near them.
 */
@Service
public class AssociationService {

    private final AssociationRequestRepository requests;
    private final UserRepository users;
    private final JdbcClient jdbc;
    private final Notifications notifications;
    private final AdminLog log;
    private final double alertRadiusM;

    public AssociationService(AssociationRequestRepository requests, UserRepository users, JdbcClient jdbc,
            Notifications notifications, AdminLog log, WinouProperties properties) {
        this.requests = requests;
        this.users = users;
        this.jdbc = jdbc;
        this.notifications = notifications;
        this.log = log;
        this.alertRadiusM = properties.associations().alertRadiusKm() * 1000;
    }

    @Transactional
    public AssociationRequestOut request(AssociationRequestIn body, User user) {
        if (user.isAssociation()) {
            throw ApiException.coded(HttpStatus.CONFLICT, "already_association", "You are already an association.");
        }
        if (requests.existsByUserIdAndStatus(user.getId(), RequestStatus.PENDING)) {
            throw pending();
        }
        AssociationRequest request = new AssociationRequest();
        request.setUserId(user.getId());
        request.setOrganisation(body.organisation().strip());
        request.setCity(body.city().strip());
        request.setContact(body.contact().strip());
        request.setNote(body.note() == null || body.note().isBlank() ? null : body.note().strip());
        request.setLocation(body.location().toPoint());
        try {
            requests.saveAndFlush(request);
        } catch (DataIntegrityViolationException e) {
            throw pending(); // sent twice at the same moment
        }
        return out(request, user);
    }

    /** The user's latest request, or null if they never sent one. */
    @Transactional(readOnly = true)
    public AssociationRequestOut mine(User user) {
        return requests.findFirstByUserIdOrderByCreatedAtDesc(user.getId()).map(r -> out(r, user)).orElse(null);
    }

    @Transactional(readOnly = true)
    public List<AssociationRequestOut> pending(User admin) {
        Admins.require(admin);
        List<AssociationRequest> pending = requests.findByStatusOrderByCreatedAt(RequestStatus.PENDING);
        Map<UUID, User> byId = users.findAllById(pending.stream().map(AssociationRequest::getUserId).toList())
                .stream().collect(Collectors.toMap(User::getId, Function.identity()));
        return pending.stream().map(r -> out(r, byId.get(r.getUserId()))).toList();
    }

    @Transactional
    public AssociationRequestOut decide(UUID id, boolean approve, User admin) {
        Admins.require(admin);
        AssociationRequest request = requests.findById(id)
                .orElseThrow(() -> ApiException.notFound("Association request"));
        if (request.getStatus() != RequestStatus.PENDING) {
            throw ApiException.coded(HttpStatus.CONFLICT, "already_decided", "This request was already decided.");
        }
        User user = users.findById(request.getUserId()).orElseThrow();
        request.setStatus(approve ? RequestStatus.APPROVED : RequestStatus.REJECTED);
        request.setDecidedAt(OffsetDateTime.now());
        request.setDecidedBy(admin.getId());
        if (approve) {
            if (user.getRole() == Role.USER) {
                user.setRole(Role.ASSOCIATION); // an admin keeps their role, and gets the name and alerts too
            }
            user.setAssociationName(request.getOrganisation());
            user.setAlertLocation(request.getLocation());
            users.save(user);
        }
        log.record(admin, approve ? AdminAction.APPROVE_ASSOCIATION : AdminAction.REJECT_ASSOCIATION,
                "ASSOCIATION_REQUEST", request.getId(), user.getId(), request.getOrganisation());
        notifications.send(n -> n.associationDecided(request));
        return out(request, user);
    }

    /** Associations whose alert area contains the point, except the given user (who reported it). */
    public List<UUID> near(GeoPoint point, UUID except) {
        return jdbc.sql("""
                        SELECT id FROM users
                        WHERE association_name IS NOT NULL AND alert_point IS NOT NULL AND id <> :except
                          AND ST_DWithin(alert_point, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radius)""")
                .param("lat", point.lat())
                .param("lon", point.lon())
                .param("radius", alertRadiusM)
                .param("except", except)
                .query(UUID.class)
                .list();
    }

    private static AssociationRequestOut out(AssociationRequest r, User user) {
        return new AssociationRequestOut(r.getId(), r.getOrganisation(), r.getCity(), r.getContact(), r.getNote(),
                Location.of(r.getLocation()), r.getStatus(), user == null ? null : user.getDisplayName(),
                user == null ? null : user.getEmail(), r.getCreatedAt(), r.getDecidedAt());
    }

    private static ApiException pending() {
        return ApiException.coded(HttpStatus.CONFLICT, "request_pending", "Your request is being reviewed.");
    }
}
