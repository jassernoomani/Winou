package tn.winou.infra;

import java.util.List;

/** Object storage for photos. The bucket is private; the API serves the images itself. */
public interface Storage {

    void put(String key, byte[] data, String contentType);

    byte[] get(String key);

    void delete(List<String> keys);
}
