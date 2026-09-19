package com.claude.cicd.api.status;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Exposes the runtime status endpoint used as the smoke test target by the staging,
 * production, and rollback workflows.
 *
 * <p>Both values are resolved at startup so that a running instance reports the artifact
 * it was built from and the environment it was deployed to.
 */
@RestController
public class StatusController {

    private final String version;
    private final String environment;

    /**
     * @param version     Maven project version, resolved from {@code build.version}
     * @param environment deployment environment, resolved from {@code app.environment}
     */
    public StatusController(@Value("${build.version}") String version,
                            @Value("${app.environment}") String environment) {
        this.version = version;
        this.environment = environment;
    }

    @GetMapping("/api/v1/status")
    public StatusResponse getStatus() {
        return new StatusResponse("UP", version, environment);
    }
}
