package com.claude.cicd.payment.api;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

import com.claude.cicd.payment.application.CreatePaymentService;
import com.claude.cicd.payment.domain.Currency;
import com.claude.cicd.payment.domain.Payment;

@RestController
@RequestMapping("/api/v1/payments")
public class PaymentController {

    private final CreatePaymentService createPaymentService;

    public PaymentController(CreatePaymentService createPaymentService) {
        this.createPaymentService = createPaymentService;
    }

    @PostMapping
    public ResponseEntity<PaymentResponse> createPayment(@Valid @RequestBody CreatePaymentRequest request) {
        Payment payment = createPaymentService.createPayment(
                request.amount(),
                Currency.valueOf(request.currency()),
                request.description());
        return ResponseEntity.status(HttpStatus.CREATED).body(PaymentResponse.from(payment));
    }
}
