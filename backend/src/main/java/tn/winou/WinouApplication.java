package tn.winou;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

/** Winou API. With WINOU_WORKER_ENABLED=true the same application processes uploaded photos. */
@SpringBootApplication
@ConfigurationPropertiesScan
public class WinouApplication {

    public static void main(String[] args) {
        SpringApplication.run(WinouApplication.class, args);
    }
}
