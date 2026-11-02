package tn.winou.chat;

import java.util.regex.Pattern;

/**
 * Spots the classic lost-pet scam in a chat message: asking for money before a handover, or a
 * link to pay or "verify". The recipient sees a warning on the message; nothing is blocked (an
 * owner offering a reward is normal). English, French, Arabic and Tunisian (Latin script).
 */
public final class ScamCheck {

    public static final String PAYMENT = "payment";
    public static final String LINK = "link";

    private ScamCheck() {}

    // Latin script: whole words. "reward" / "récompense" are left out on purpose: owners offer them.
    private static final Pattern PAYMENT_LATIN = Pattern.compile("""
            (?iu)\\b(
              pay(ment|ing)?|send\\s+(me\\s+)?(the\\s+)?money|money\\s+transfer|transfer|wire|western\\s+union|
              moneygram|paypal|deposit|upfront|in\\s+advance|fees?|gift\\s+cards?|bitcoin|crypto|
              payer|payez|paie(ment|z)?|virement|mandat|envoy(er|ez)\\s+(de\\s+l'|l')?argent|frais|avance|acompte|
              recharges?|carte\\s+cadeau|
              d17|flouci|e-?dinar|sobflous|
              flous|5alles|5alless|khalles|khales|ab3ath(li)?\\s+flous
            )\\b""".replaceAll("\\s*\\n\\s*", ""));

    // Arabic script: inside words too, since they take prefixes (و، ب، ال)
    private static final Pattern PAYMENT_ARABIC = Pattern.compile(
            "ادفع|الدفع|دفع|حوالة|تحويل|فلوس|رسوم|شحن|رصيد|عربون|مقدما|مسبقا");

    private static final Pattern LINK_PATTERN = Pattern.compile("(?i)(https?://|www\\.)(?!winou\\.duckdns\\.org)");

    /** "payment", "link", or null when the message looks fine. */
    public static String warning(String body) {
        if (body == null || body.isBlank()) {
            return null;
        }
        if (PAYMENT_LATIN.matcher(body).find() || PAYMENT_ARABIC.matcher(body).find()) {
            return PAYMENT;
        }
        return LINK_PATTERN.matcher(body).find() ? LINK : null;
    }
}
