package com.claude.cicd.api.status;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class StatusController {

    private final String version;
    private final String environment;

    public StatusController(@Value("${build.version}") String version,
                             @Value("${app.environment}") String environment) {
        this.version = version;
        this.environment = environment;
    }

    @GetMapping("/api/v1/status")
    public StatusResponse getStatus() {
        return new StatusResponse("UP", version, environment, "Service is running", "status");
    }
}