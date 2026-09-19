package com.claude.cicd.api.status;

import org.junit.jupiter.api.Test;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Pins {@code build.version} and {@code app.environment} so the assertions stay
 * independent from the ambient environment of the machine running the build.
 */
@WebMvcTest(
        controllers = StatusController.class,
        properties = {
                "build.version=0.0.1-TEST",
                "app.environment=test"
        }
)
class StatusControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void shouldReturnUpStatus() throws Exception {
        mockMvc.perform(get("/api/v1/status"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("application/json"))
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.version").value("0.0.1-TEST"))
                .andExpect(jsonPath("$.environment").value("test"));
    }
}
