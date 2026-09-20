package com.claude.cicd.payment.infrastructure.persistence;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Repository;

import com.claude.cicd.payment.domain.Payment;
import com.claude.cicd.payment.domain.PaymentRepository;

/**
 * Temporary in-memory {@link PaymentRepository} adapter.
 *
 * <p>Intended to be replaced by a PostgreSQL-backed adapter without any change to the
 * domain model or the use case layer.
 */
@Repository
public class InMemoryPaymentRepository implements PaymentRepository {

    private final Map<UUID, Payment> payments = new ConcurrentHashMap<>();

    @Override
    public Payment save(Payment payment) {
        payments.put(payment.id(), payment);
        return payment;
    }
}
