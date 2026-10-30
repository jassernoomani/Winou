package tn.winou.security;

import java.util.UUID;

import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

import tn.winou.common.ApiException;
import tn.winou.domain.User;
import tn.winou.domain.UserRepository;

/** Loads the user named by the token. A valid token for a deleted or banned account is rejected too. */
@Component
public class CurrentUserResolver implements HandlerMethodArgumentResolver {

    private final UserRepository users;

    public CurrentUserResolver(UserRepository users) {
        this.users = users;
    }

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(CurrentUser.class) && parameter.getParameterType() == User.class;
    }

    @Override
    public User resolveArgument(MethodParameter parameter, ModelAndViewContainer mavContainer,
            NativeWebRequest webRequest, WebDataBinderFactory binderFactory) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken token)) {
            throw ApiException.unauthorized("Not authenticated");
        }
        User user;
        try {
            user = users.findById(UUID.fromString(token.getName()))
                    .orElseThrow(() -> ApiException.unauthorized("Invalid or expired token"));
        } catch (IllegalArgumentException e) {
            throw ApiException.unauthorized("Invalid or expired token");
        }
        requireNotBanned(user);
        return user;
    }

    /** A ban takes effect at once, on tokens issued before it too. */
    public static void requireNotBanned(User user) {
        if (user.isBanned()) {
            throw ApiException.banned(user.getBannedUntil(), user.getBanReason());
        }
    }

    /** Owners may change their own records; admins may change any. */
    public static void requireOwnerOrAdmin(User user, UUID ownerId) {
        if (!user.getId().equals(ownerId) && user.getRole() != tn.winou.domain.Role.ADMIN) {
            throw ApiException.forbidden();
        }
    }
}
