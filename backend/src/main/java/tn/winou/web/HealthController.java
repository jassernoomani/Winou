package tn.winou.web;

import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@Tag(name = "health")
public class HealthController {

    private final JdbcClient jdbc;

    public HealthController(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        jdbc.sql("SELECT 1").query(Integer.class).single();
        return Map.of("status", "ok");
    }
}
