package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;

import tn.winou.infra.MlClient.Embedding;
import tn.winou.photos.Images.PublicCopy;

/** Records holding image bytes compare by content and never print the bytes. */
class ByteRecordsTest {

    @Test
    void embeddingsCompareByContent() {
        var a = new Embedding("cat", 0.9, List.of(0.1, 0.2), new byte[] {1, 2, 3});
        var same = new Embedding("cat", 0.9, List.of(0.1, 0.2), new byte[] {1, 2, 3});
        var otherCrop = new Embedding("cat", 0.9, List.of(0.1, 0.2), new byte[] {1, 2, 4});
        var otherSpecies = new Embedding("dog", 0.9, List.of(0.1, 0.2), new byte[] {1, 2, 3});

        assertThat(a).isEqualTo(same).hasSameHashCodeAs(same).isNotEqualTo(otherCrop).isNotEqualTo(otherSpecies)
                .isNotEqualTo("cat");
        assertThat(a).hasToString("Embedding[species=cat, confidence=0.9, dim=2, cropJpeg=3 bytes]");
    }

    @Test
    void publicCopiesCompareByContent() {
        var a = new PublicCopy(new byte[] {1, 2}, "image/jpeg");
        var same = new PublicCopy(new byte[] {1, 2}, "image/jpeg");
        var otherBytes = new PublicCopy(new byte[] {2, 1}, "image/jpeg");
        var otherType = new PublicCopy(new byte[] {1, 2}, "image/heif");

        assertThat(a).isEqualTo(same).hasSameHashCodeAs(same).isNotEqualTo(otherBytes).isNotEqualTo(otherType)
                .isNotEqualTo(null);
        assertThat(a).hasToString("PublicCopy[jpeg=2 bytes, originalType=image/jpeg]");
    }
}
