package tn.winou.infra;

import java.util.ArrayList;
import java.util.Base64;
import java.util.List;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import tools.jackson.databind.JsonNode;
import tn.winou.config.WinouProperties;

@Component
public class HttpMlClient implements MlClient {

    private final RestClient http;

    public HttpMlClient(WinouProperties properties) {
        var requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(10_000);
        requestFactory.setReadTimeout((int) properties.ml().timeout().toMillis()); // first call loads the models
        this.http = RestClient.builder().baseUrl(properties.ml().url()).requestFactory(requestFactory).build();
    }

    @Override
    public Embedding embed(byte[] image) {
        return http.post().uri("/embed?return_crop=true")
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(file(image))
                .exchange((request, response) -> {
                    JsonNode body = response.bodyTo(JsonNode.class);
                    if (response.getStatusCode().value() == 422 && body != null
                            && "no_animal_detected".equals(body.path("detail").path("code").asString())) {
                        throw new NoAnimalDetected();
                    }
                    if (response.getStatusCode().isError() || body == null) {
                        throw new IllegalStateException("ml-service /embed returned " + response.getStatusCode());
                    }
                    List<Double> vector = new ArrayList<>();
                    body.path("vector").forEach(v -> vector.add(v.asDouble()));
                    JsonNode detection = body.path("detection");
                    return new Embedding(detection.path("species").asString(),
                            detection.path("confidence").asDouble(), vector,
                            Base64.getDecoder().decode(body.path("crop_jpeg_base64").asString()));
                });
    }

    @Override
    public byte[] heicToJpeg(byte[] image, int maxSide) {
        return http.post().uri("/convert?max_side={side}", maxSide)
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(file(image))
                .retrieve()
                .body(byte[].class);
    }

    private static MultiValueMap<String, Object> file(byte[] image) {
        MultiValueMap<String, Object> parts = new LinkedMultiValueMap<>();
        parts.add("file", new ByteArrayResource(image) {
            @Override
            public String getFilename() {
                return "photo.jpg";
            }
        });
        return parts;
    }
}
