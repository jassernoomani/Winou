package tn.winou.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.Role;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;

/** Admins are the accounts listed in ADMIN_EMAILS: promoted at startup, or when they register. */
@Component
public class Admins implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(Admins.class);

    private final UserRepository users;
    private final WinouProperties.Admin admin;

    public Admins(UserRepository users, WinouProperties properties) {
        this.users = users;
        this.admin = properties.admin();
    }

    public static void require(User user) {
        if (user.getRole() != Role.ADMIN) {
            throw ApiException.forbidden();
        }
    }

    /** For a new account: ADMIN if its email is listed, USER otherwise. */
    public Role roleFor(String email) {
        return admin.isAdmin(email) ? Role.ADMIN : Role.USER;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        for (String email : admin.emails()) {
            users.findByEmail(email).filter(u -> u.getRole() != Role.ADMIN).ifPresent(u -> {
                u.setRole(Role.ADMIN);
                users.save(u);
                log.info("{} is now an admin (ADMIN_EMAILS)", email);
            });
        }
    }
}
