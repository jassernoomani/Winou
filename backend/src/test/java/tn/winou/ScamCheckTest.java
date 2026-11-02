package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import tn.winou.chat.ScamCheck;

/** Which chat messages get a warning. Owners talking about a reward must not. */
class ScamCheckTest {

    @ParameterizedTest
    @ValueSource(strings = {
            "Send me money first and I'll bring the dog",
            "You need to pay the vet fees before I give it back",
            "Please transfer 200 dt upfront",
            "Western Union is fine",
            "Envoyez l'argent par virement et je vous l'amène",
            "Il faut payer les frais de garde d'abord",
            "Faites-moi un mandat minute",
            "Send it on D17 please",
            "Flouci or e-dinar?",
            "ab3athli flous 9bal",
            "5alles 9bal w njiblek el kalb",
            "لازم تدفع قبل",
            "ابعث الفلوس بالحوالة",
            "اشحن لي رصيد وأعطيك القط",
    })
    void asksForMoney(String message) {
        assertThat(ScamCheck.warning(message)).isEqualTo(ScamCheck.PAYMENT);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "Verify here: https://bit.ly/x7k2",
            "go to www.example.com to confirm",
    })
    void linksElsewhere(String message) {
        assertThat(ScamCheck.warning(message)).isEqualTo(ScamCheck.LINK);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "Thank you so much! I'll give you the reward when we meet",
            "Merci, la récompense est pour vous",
            "She's near the pharmacy, by the bakery",
            "Her paws are white",
            "Can we meet at 5 at the park?",
            "شكرا جزيلا، سأعطيك المكافأة عند اللقاء",
            "Here's the poster: https://winou.duckdns.org/lost/123",
            "",
    })
    void looksFine(String message) {
        assertThat(ScamCheck.warning(message)).isNull();
    }
}
