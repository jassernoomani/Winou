package tn.winou.config;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.Executors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.auth.oauth2.ServiceAccountCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;

import tn.winou.domain.LostReportRepository;
import tn.winou.domain.SightingRepository;
import tn.winou.domain.UserRepository;
import tn.winou.infra.FirebaseSender;
import tn.winou.infra.Inbox;
import tn.winou.infra.LogSender;
import tn.winou.infra.Notifications;
import tn.winou.infra.Notifier;
import tn.winou.infra.PushNotifier;

/** Push notifications when a Firebase service account key is configured, log lines otherwise. */
@Configuration
public class NotifierConfig {

    private static final Logger log = LoggerFactory.getLogger(NotifierConfig.class);

    @Bean
    Notifier notifier(WinouProperties properties, LostReportRepository reports, SightingRepository sightings,
            UserRepository users, Inbox inbox) throws IOException {
        String keyFile = properties.firebase().credentials();
        if (keyFile == null || keyFile.isBlank()) {
            log.info("FIREBASE_CREDENTIALS is not set: notifications are logged, not pushed");
            return new PushNotifier(new LogSender(), reports, sightings, users, inbox);
        }
        Path key = Path.of(keyFile);
        if (!Files.isRegularFile(key)) {
            log.warn("Firebase key {} not found: notifications are logged, not pushed", key);
            return new PushNotifier(new LogSender(), reports, sightings, users, inbox);
        }
        try (InputStream in = Files.newInputStream(key)) {
            GoogleCredentials credentials = GoogleCredentials.fromStream(in);
            FirebaseOptions options = FirebaseOptions.builder().setCredentials(credentials).build();
            FirebaseApp app = FirebaseApp.initializeApp(options, "winou");
            log.info("push notifications enabled (Firebase project {})",
                    credentials instanceof ServiceAccountCredentials account ? account.getProjectId() : "?");
            return new PushNotifier(new FirebaseSender(FirebaseMessaging.getInstance(app)), reports, sightings,
                    users, inbox);
        }
    }

    @Bean
    Notifications notifications(Notifier notifier) {
        return new Notifications(notifier, Executors.newVirtualThreadPerTaskExecutor());
    }
}
