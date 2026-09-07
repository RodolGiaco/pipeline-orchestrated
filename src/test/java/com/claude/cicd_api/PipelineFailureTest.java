package com.claude.cicd_api;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.fail;

class PipelineFailureTest {

    @Test
    void shouldFailForPipelineValidation() {
        fail("Intentional failure for pipeline validation");
    }
}