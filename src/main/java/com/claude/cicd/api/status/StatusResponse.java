package com.claude.cicd.api.status;

public record StatusResponse(String status, String version, String environment, String description, String component) {
}