package com.example.backend;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

/**
 * Verifies the access-control rules without contacting Auth0:
 * the jwt() post-processor injects an already-validated token.
 */
@SpringBootTest
class RiskControllerSecurityTests {

    @Autowired
    private WebApplicationContext context;

    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
    }

    @Test
    void requestWithoutTokenIsRejectedWith401() throws Exception {
        mvc.perform(get("/api/risk-status")).andExpect(status().isUnauthorized());
    }

    @Test
    void requestWithValidTokenReturnsProtectedStatus() throws Exception {
        mvc.perform(get("/api/risk-status").with(jwt().jwt(token -> token.subject("auth0|test-user"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("protected"))
            .andExpect(jsonPath("$.subject").value("auth0|test-user"));
    }

    @Test
    void unknownPathsAreDeniedEvenWithToken() throws Exception {
        mvc.perform(get("/admin").with(jwt())).andExpect(status().isForbidden());
    }
}
