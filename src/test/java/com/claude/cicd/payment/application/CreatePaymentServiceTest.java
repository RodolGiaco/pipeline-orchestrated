package com.claude.cicd.payment.application;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.claude.cicd.payment.domain.Currency;
import com.claude.cicd.payment.domain.Payment;
import com.claude.cicd.payment.domain.PaymentStatus;
import com.claude.cicd.payment.infrastructure.persistence.InMemoryPaymentRepository;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class CreatePaymentServiceTest {

    private final CreatePaymentService service = new CreatePaymentService(new InMemoryPaymentRepository());

    @Test
    void shouldCreatePaymentInCreatedStatusWithGeneratedIdAndTimestamp() {
        Payment payment = service.createPayment(new BigDecimal("100.00"), Currency.USD, "Order payment");

        assertNotNull(payment.id());
        assertEquals(PaymentStatus.CREATED, payment.status());
        assertNotNull(payment.createdAt());
        assertEquals(0, new BigDecimal("100.00").compareTo(payment.amount()));
        assertEquals(Currency.USD, payment.currency());
        assertEquals("Order payment", payment.description());
    }

    @Test
    void shouldGenerateDifferentIdsForEachPayment() {
        Payment first = service.createPayment(new BigDecimal("1.00"), Currency.ARS, null);
        Payment second = service.createPayment(new BigDecimal("1.00"), Currency.ARS, null);

        assertNotEquals(first.id(), second.id());
    }
}
