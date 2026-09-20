package com.claude.cicd.payment.domain;

/**
 * Storage abstraction for payments, independent from any concrete persistence mechanism.
 */
public interface PaymentRepository {

    Payment save(Payment payment);
}
