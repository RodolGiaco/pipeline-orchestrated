package com.claude.cicd.api.status;

/**
 * Payload returned by the status endpoint.
 *
 * <p>The staging, production, and rollback workflows parse this payload and require
 * {@code status} to be {@code "UP"} before treating a deployment as successful.
 *
 * @param status      liveness indicator; {@code "UP"} while the service is serving traffic
 * @param version     Maven project version, injected at build time
 * @param environment deployment environment reported by the running instance
 */
public record StatusResponse(String status, String version, String environment) {
}
