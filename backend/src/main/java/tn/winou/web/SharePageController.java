package tn.winou.web;

import java.time.format.DateTimeFormatter;
import java.time.format.FormatStyle;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

import io.swagger.v3.oas.annotations.Hidden;
import jakarta.servlet.http.HttpServletRequest;
import tn.winou.config.WinouProperties;
import tn.winou.domain.LostReport;
import tn.winou.domain.LostReportRepository;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.ReportStatus;
import tn.winou.domain.Species;

/**
 * What a shared lost-pet link shows: with the app installed, Android opens the app at the report
 * (assetlinks.json); otherwise this page, whose preview tags put the photo in WhatsApp and Facebook.
 */
@RestController
@Hidden
public class SharePageController {

    private final LostReportRepository reports;
    private final PhotoRepository photos;
    private final Views views;
    private final WinouProperties.Share share;

    public SharePageController(LostReportRepository reports, PhotoRepository photos, Views views,
            WinouProperties properties) {
        this.reports = reports;
        this.photos = photos;
        this.views = views;
        this.share = properties.share();
    }

    @GetMapping(value = "/.well-known/assetlinks.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<Map<String, Object>> assetLinks() {
        return List.of(Map.of(
                "relation", List.of("delegate_permission/common.handle_all_urls"),
                "target", Map.of("namespace", "android_app", "package_name", share.androidPackage(),
                        "sha256_cert_fingerprints", List.of(share.androidCertSha256()))));
    }

    @GetMapping(value = "/lost/{id}", produces = MediaType.TEXT_HTML_VALUE)
    @Transactional(readOnly = true)
    public ResponseEntity<String> lostPet(@PathVariable String id, HttpServletRequest request) {
        Text t = Text.of(request.getLocale());
        String base = ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
        LostReport report = parse(id) == null ? null : reports.findById(parse(id))
                .filter(r -> views.canSee(r.getOwnerId(), r.getHiddenAt(), null))
                .orElse(null);
        if (report == null || report.getStatus() != ReportStatus.OPEN) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).contentType(MediaType.TEXT_HTML)
                    .body(page(t.lang, t.gone, null, null, """
                            <h1>%s</h1><p>%s</p>""".formatted(esc(t.gone), esc(t.goneBody)), base, t));
        }
        Photo photo = photos.findByLostReportIdInOrderByCreatedAt(List.of(report.getId())).stream().findFirst()
                .orElse(null);
        String image = photo == null ? null : base + Views.imageUrl(photo.getId());
        String title = t.lost(report.getSpecies()) + " · " + report.getName();
        String seen = t.lastSeen + " " + report.getLastSeenAt()
                .format(DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT).withLocale(t.locale));
        String description = report.getDescription() == null ? "" : report.getDescription();
        String reward = report.getRewardTnd() == null ? "" : "<p class=\"tag\">" + esc(t.reward(report.getRewardTnd())) + "</p>";
        String body = """
                %s
                <p class="tag">%s</p>
                <h1>%s</h1>
                <p class="seen">%s</p>
                %s
                %s
                <p>%s</p>""".formatted(
                image == null ? "" : "<img class=\"photo\" src=\"" + esc(image) + "\" alt=\"" + esc(report.getName()) + "\">",
                esc(t.lost(report.getSpecies())), esc(report.getName()), esc(seen), reward,
                description.isBlank() ? "" : "<p>" + esc(description) + "</p>", esc(t.help));
        return ResponseEntity.ok().contentType(MediaType.TEXT_HTML)
                .cacheControl(CacheControl.maxAge(java.time.Duration.ofMinutes(5)))
                .body(page(t.lang, title, seen + (description.isBlank() ? "" : " · " + description), image, body,
                        base, t));
    }

    private static UUID parse(String id) {
        try {
            return UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private static String page(String lang, String title, String description, String image, String body,
            String base, Text t) {
        String meta = """
                <meta property="og:title" content="%s">
                <meta property="og:site_name" content="Winou">
                <meta property="og:type" content="website">""".formatted(esc(title));
        if (description != null) {
            meta += "\n<meta property=\"og:description\" content=\"" + esc(description) + "\">"
                    + "\n<meta name=\"description\" content=\"" + esc(description) + "\">";
        }
        if (image != null) {
            meta += "\n<meta property=\"og:image\" content=\"" + esc(image) + "\">"
                    + "\n<meta name=\"twitter:card\" content=\"summary_large_image\">";
        }
        return """
                <!doctype html>
                <html lang="%s" dir="%s">
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>%s</title>
                %s
                <style>
                  body{margin:0;background:#F5F7FC;color:#111D36;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
                  main{max-width:480px;margin:0 auto;padding:16px}
                  .brand{font-weight:900;font-size:22px;color:#3884FF;margin:4px 0 16px}
                  .card{background:#fff;border-radius:24px;padding:20px;box-shadow:0 2px 12px rgba(17,29,54,.08)}
                  .photo{width:100%%;aspect-ratio:4/3;object-fit:cover;border-radius:18px}
                  .tag{display:inline-block;margin:16px 0 4px;padding:4px 12px;border-radius:99px;background:#FFE4E8;color:#BE123C;font-weight:800;font-size:13px}
                  h1{margin:4px 0;font-size:32px}
                  .seen{color:#526079;margin-top:0}
                  .button{display:block;text-align:center;text-decoration:none;font-weight:800;padding:14px;border-radius:99px;margin-top:12px}
                  .primary{background:#3884FF;color:#111D36}
                  .secondary{border:2px solid #3884FF;color:#294AB8}
                  @media (prefers-color-scheme:dark){body{background:#0F1726;color:#EEF2FA}.card{background:#1C283C}.seen{color:#9AA8C2}.secondary{color:#9DBBFF}}
                </style>
                </head>
                <body><main>
                <p class="brand">winou</p>
                <div class="card">
                %s
                </div>
                <a class="button primary" href="%s/download/winou.apk">%s</a>
                <p class="seen" style="text-align:center;font-size:14px">%s</p>
                </main></body>
                </html>""".formatted(lang, "ar".equals(lang) ? "rtl" : "ltr", esc(title), meta, body, base,
                esc(t.getApp), esc(t.tagline));
    }

    static String esc(String text) {
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
    }

    /** The page's words, in French, Arabic or English from the browser's language. */
    private record Text(String lang, Locale locale, String cat, String dog, String pet, String lastSeen,
            String help, String getApp, String tagline, String gone, String goneBody) {

        static Text of(Locale requested) {
            if ("ar".equals(requested.getLanguage())) {
                return new Text("ar", Locale.forLanguageTag("ar-DZ"), "قطّ ضائع", "كلب ضائع", "حيوان ضائع",
                        "آخر مشاهدة:",
                        "هل رأيت هذا الحيوان؟ أبلغ عنه في تطبيق Winou: سيُبلَّغ المالك فورًا.",
                        "حمّل Winou (Android)", "Winou: ابحث عن الحيوانات الضائعة وساعد حيوانات الشارع.",
                        "لم يعد مفقودًا", "لم يعد هذا الحيوان مُدرجًا كضائع. شكرًا على مساعدتك!");
            }
            if ("fr".equals(requested.getLanguage())) {
                return new Text("fr", Locale.FRENCH, "Chat perdu", "Chien perdu", "Animal perdu", "Vu pour la dernière fois le",
                        "Vous l'avez vu ? Signalez-le dans l'application Winou : le propriétaire est prévenu tout de suite.",
                        "Installer Winou (Android)", "Winou : retrouver les animaux perdus, aider les animaux des rues.",
                        "Plus recherché", "Cet animal n'est plus signalé comme perdu. Merci d'avoir aidé !");
            }
            return new Text("en", Locale.ENGLISH, "Lost cat", "Lost dog", "Lost pet", "Last seen",
                    "Seen this pet? Report it in the Winou app: the owner hears about it at once.",
                    "Get Winou (Android)", "Winou: find lost pets, help street animals.",
                    "No longer missing", "This pet isn't listed as missing anymore. Thanks for helping!");
        }

        String reward(int tnd) {
            return switch (lang) {
                case "fr" -> "Récompense : " + tnd + " DT";
                case "ar" -> "مكافأة: " + tnd + " د.ت";
                default -> "Reward: " + tnd + " TND";
            };
        }

        String lost(Species species) {
            return switch (species) {
                case CAT -> cat;
                case DOG -> dog;
                case OTHER -> pet;
            };
        }
    }
}
