package com.claude.cicd.payment.application;

import java.math.BigDecimal;

import org.springframework.stereotype.Service;

import com.claude.cicd.payment.domain.Currency;
import com.claude.cicd.payment.domain.Payment;
import com.claude.cicd.payment.domain.PaymentRepository;

/**
 * Use case for creating a payment.
 *
 * <p>Depends only on the domain model and the {@link PaymentRepository} abstraction, so it
 * remains independent from Spring MVC and from the concrete storage implementation.
 */
@Service
public class CreatePaymentService {

    private final PaymentRepository paymentRepository;

    public CreatePaymentService(PaymentRepository paymentRepository) {
        this.paymentRepository = paymentRepository;
    }

    public Payment createPayment(BigDecimal amount, Currency currency, String description) {
        Payment payment = Payment.create(amount, currency, description);
        return paymentRepository.save(payment);
    }
}
