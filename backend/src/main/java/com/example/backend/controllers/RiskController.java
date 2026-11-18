package com.example.backend.controllers;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class RiskController {

    private static final Logger log = LoggerFactory.getLogger(RiskController.class);

    @GetMapping("/risk-status")
    public Map<String, Object> riskStatus(@AuthenticationPrincipal Jwt jwt) {
        // Audit trail (journalctl -u enterprise-risk-api). Never log the token itself.
        log.info("AUDIT access granted to /api/risk-status subject={}", jwt.getSubject());
        return Map.of(
            "status", "protected",
            "subject", jwt.getSubject(),
            "control", "JWT validation and authenticated access"
        );
    }
}
