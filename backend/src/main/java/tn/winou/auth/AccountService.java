package tn.winou.auth;

import java.time.Duration;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Sighting;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;
import tn.winou.reports.LostReportService;
import tn.winou.security.AttemptLimiter;
import tn.winou.security.Passwords;
import tn.winou.security.Sessions;
import tn.winou.sightings.SightingService;
import tn.winou.web.ApiModels.DeleteAccountIn;
import tn.winou.web.ApiModels.PasswordChangeIn;
import tn.winou.web.ApiModels.TokenOut;

/** What people do with their own account: password, signing out everywhere, deleting it. */
@Service
public class AccountService {

    private static final Logger log = LoggerFactory.getLogger(AccountService.class);

    private final UserRepository users;
    private final Passwords passwords;
    private final Sessions sessions;
    private final AttemptLimiter limiter;
    private final LostReportRepository reports;
    private final SightingRepository sightings;
    private final LostReportService reportService;
    private final SightingService sightingService;
    private final WinouProperties.Auth settings;

    public AccountService(UserRepository users, Passwords passwords, Sessions sessions, AttemptLimiter limiter,
            LostReportRepository reports, SightingRepository sightings, LostReportService reportService,
            SightingService sightingService, WinouProperties properties) {
        this.users = users;
        this.passwords = passwords;
        this.sessions = sessions;
        this.limiter = limiter;
        this.reports = reports;
        this.sightings = sightings;
        this.reportService = reportService;
        this.sightingService = sightingService;
        this.settings = properties.auth();
    }

    /** Someone else who has the password may be signed in: every other phone is signed out. */
    @Transactional
    public TokenOut changePassword(PasswordChangeIn body, User user) {
        requirePassword(user, body.currentPassword());
        user.setPasswordHash(passwords.hash(body.newPassword()));
        sessions.endAll(user);
        return sessions.start(user);
    }

    @Transactional
    public void signOutEverywhere(User user) {
        sessions.endAll(user);
    }

    /** Lost reports and sightings go through their services, so their photos and vectors go too. */
    @Transactional
    public void delete(DeleteAccountIn body, User user) {
        requirePassword(user, body.password());
        for (LostReport report : reports.findByOwnerIdOrderByCreatedAtDesc(user.getId())) {
            reportService.delete(report.getId(), user);
        }
        for (Sighting sighting : sightings.findByReporterIdOrderByCreatedAtDesc(user.getId())) {
            sightingService.delete(sighting.getId(), user);
        }
        users.delete(user); // sessions, matches, conversations and reports cascade in Postgres
        log.info("user {} deleted their account", user.getId());
    }

    /** The current password, with the same limit on wrong guesses as signing in. */
    private void requirePassword(User user, String password) {
        String key = "login:" + user.getEmail();
        Duration window = settings.loginAttemptWindow();
        limiter.check(key, settings.loginAttemptsPerEmail(), window);
        if (!passwords.verify(user.getPasswordHash(), password)) {
            limiter.record(key, window);
            throw ApiException.coded(HttpStatus.FORBIDDEN, "wrong_password", "The password is wrong.");
        }
        limiter.clear(key);
    }
}
