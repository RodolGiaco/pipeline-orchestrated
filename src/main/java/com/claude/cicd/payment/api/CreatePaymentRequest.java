package com.claude.cicd.payment.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/**
 * Request payload for {@code POST /api/v1/payments}.
 */
public record CreatePaymentRequest(

        @NotNull(message = "amount is required")
        @DecimalMin(value = "0.0", inclusive = false, message = "amount must be greater than zero")
        BigDecimal amount,

        @NotBlank(message = "currency is required")
        @Pattern(regexp = "ARS|USD", message = "currency must be one of: ARS, USD")
        String currency,

        String description) {
}
