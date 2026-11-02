package tn.winou.infra;

import java.util.List;
import java.util.Optional;

/** Object storage for photos. The bucket is private; the API serves the images itself. */
public interface Storage {

    void put(String key, byte[] data, String contentType);

    byte[] get(String key);

    /** Empty if there is no such object; other failures (storage down) still throw. */
    Optional<byte[]> find(String key);

    void delete(List<String> keys);
}
