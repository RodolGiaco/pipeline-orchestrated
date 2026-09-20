package com.claude.cicd.payment.api;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import com.claude.cicd.payment.domain.Payment;

/**
 * Response payload for payment operations.
 */
public record PaymentResponse(
        UUID id,
        BigDecimal amount,
        String currency,
        String status,
        String description,
        Instant createdAt) {

    public static PaymentResponse from(Payment payment) {
        return new PaymentResponse(
                payment.id(),
                payment.amount(),
                payment.currency().name(),
                payment.status().name(),
                payment.description(),
                payment.createdAt());
    }
}
