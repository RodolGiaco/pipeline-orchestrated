package com.claude.cicd.payment.api;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.web.servlet.MockMvc;

import com.claude.cicd.api.CicdApiApplication;
import com.claude.cicd.payment.application.CreatePaymentService;
import com.claude.cicd.payment.infrastructure.persistence.InMemoryPaymentRepository;

import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = PaymentController.class)
@ContextConfiguration(classes = CicdApiApplication.class)
@Import({CreatePaymentService.class, InMemoryPaymentRepository.class})
class PaymentControllerTest {

    private static final String UUID_PATTERN =
            "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$";

    @Autowired
    private MockMvc mockMvc;

    @Test
    void shouldCreatePaymentWithGeneratedIdStatusAndTimestamp() throws Exception {
        String requestBody = """
                {
                  "amount": 1250.50,
                  "currency": "ARS",
                  "description": "Order payment"
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id", matchesPattern(UUID_PATTERN)))
                .andExpect(jsonPath("$.amount").value(1250.50))
                .andExpect(jsonPath("$.currency").value("ARS"))
                .andExpect(jsonPath("$.status").value("CREATED"))
                .andExpect(jsonPath("$.description").value("Order payment"))
                .andExpect(jsonPath("$.createdAt").exists());
    }

    @Test
    void shouldCreatePaymentWithoutDescription() throws Exception {
        String requestBody = """
                {
                  "amount": 10.00,
                  "currency": "USD"
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("CREATED"));
    }

    @Test
    void shouldRejectMissingAmount() throws Exception {
        String requestBody = """
                {
                  "currency": "ARS"
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldRejectZeroAmount() throws Exception {
        String requestBody = """
                {
                  "amount": 0,
                  "currency": "ARS"
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldRejectNegativeAmount() throws Exception {
        String requestBody = """
                {
                  "amount": -5,
                  "currency": "ARS"
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldRejectMissingCurrency() throws Exception {
        String requestBody = """
                {
                  "amount": 10.00
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isBadRequest());
    }

    @Test
    void shouldRejectUnsupportedCurrency() throws Exception {
        String requestBody = """
                {
                  "amount": 10.00,
                  "currency": "EUR"
                }
                """;

        mockMvc.perform(post("/api/v1/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(requestBody))
                .andExpect(status().isBadRequest());
    }
}
