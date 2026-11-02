package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import io.micrometer.core.instrument.MeterRegistry;
import tn.winou.infra.AppMetrics;

/** The app-state gauges Prometheus scrapes: photo queue, reports, matches, users. */
class MetricsTest extends ApiTestBase {

    @Autowired
    MeterRegistry registry;
    @Autowired
    AppMetrics metrics;

    private double gauge(String name, String tag, String value) {
        return registry.get(name).tag(tag, value).gauge().value();
    }

    @Test
    void gaugesFollowTheDatabase() {
        String owner = register("owner");
        lostReport(owner); // one OPEN report with one photo, waiting for the worker
        metrics.refresh();
        assertThat(gauge("winou.lost.reports", "status", "OPEN")).isEqualTo(1);
        assertThat(gauge("winou.photos", "status", "PENDING")).isEqualTo(1);
        assertThat(gauge("winou.photos", "status", "FAILED")).isZero();
        assertThat(gauge("winou.users", "kind", "all")).isEqualTo(1);

        work();
        metrics.refresh();
        assertThat(gauge("winou.photos", "status", "PENDING")).isZero();
        assertThat(gauge("winou.photos", "status", "READY")).isEqualTo(1);
    }
}
