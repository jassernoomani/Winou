package tn.winou.infra;

import java.util.List;

/** The ML service (Python): animal detection, cropping and embedding. */
public interface MlClient {

    /** Detects the animal, crops it and returns its embedding. */
    Embedding embed(byte[] image);

    /** HEIC to an upright JPEG without metadata (Java has no HEIC decoder; the ML service does). */
    byte[] heicToJpeg(byte[] image, int maxSide);

    record Embedding(String species, double confidence, List<Double> vector, byte[] cropJpeg) {}

    class NoAnimalDetected extends RuntimeException {
        public NoAnimalDetected() {
            super("no animal detected");
        }
    }
}
