package com.claude.cicd_api.status;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class StatusController {

    private final String version;

    public StatusController(@Value("${build.version}") String version) {
        this.version = version;
    }

    @GetMapping("/api/v1/status")
    public StatusResponse getStatus() {
        return new StatusResponse("UP", version);
    }
}