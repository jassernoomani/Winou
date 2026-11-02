package tn.winou.infra;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;

/** The ML service (Python): animal detection, cropping and embedding. */
public interface MlClient {

    /** Detects the animal, crops it and returns its embedding. */
    Embedding embed(byte[] image);

    /** HEIC to an upright JPEG without metadata (Java has no HEIC decoder; the ML service does). */
    byte[] heicToJpeg(byte[] image, int maxSide);

    record Embedding(String species, double confidence, List<Double> vector, byte[] cropJpeg) {

        @Override
        public boolean equals(Object o) {
            return o instanceof Embedding e && species.equals(e.species) && confidence == e.confidence
                    && vector.equals(e.vector) && Arrays.equals(cropJpeg, e.cropJpeg);
        }

        @Override
        public int hashCode() {
            return Objects.hash(species, confidence, vector, Arrays.hashCode(cropJpeg));
        }

        @Override
        public String toString() {
            return "Embedding[species=%s, confidence=%s, dim=%d, cropJpeg=%d bytes]"
                    .formatted(species, confidence, vector.size(), cropJpeg.length);
        }
    }

    class NoAnimalDetected extends RuntimeException {
        public NoAnimalDetected() {
            super("no animal detected");
        }
    }
}
