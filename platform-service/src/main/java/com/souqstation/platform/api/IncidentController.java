package com.souqstation.platform.api;

import com.souqstation.platform.service.IncidentService;
import com.souqstation.schemas.events.IncidentReportedEvent;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/platform/incidents")
public class IncidentController {

    private final IncidentService incidentService;

    public IncidentController(IncidentService incidentService) {
        this.incidentService = incidentService;
    }

    /**
     * Signaler un incident pour un jeu
     * POST /platform/incidents/report?userId=U1&gameId=G1&severity=HAUTE&description=...&environment=...
     */
    @PostMapping("/report")
    public ResponseEntity<Map<String, Object>> reportIncident(
            @RequestParam String userId,
            @RequestParam String gameId,
            @RequestParam String severity,
            @RequestParam String description,
            @RequestParam(required = false) String environment
    ) {
        try {
            IncidentReportedEvent event = incidentService.reportIncident(
                    userId,
                    gameId,
                    severity,
                    description,
                    environment
            );

            return ResponseEntity.ok(Map.of(
                    "status", "INCIDENT_REPORTED",
                    "eventId", event.getEventId(),
                    "incidentId", event.getIncidentId(),
                    "gameId", event.getGameId(),
                    "userId", event.getUserId(),
                    "severity", event.getSeverity().name(),
                    "reportedAt", event.getReportedAt().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "INCIDENT_REJECTED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Récupérer tous les incidents d'un jeu
     * GET /platform/incidents/game/{gameId}
     */
    @GetMapping("/game/{gameId}")
    public ResponseEntity<Map<String, Object>> getIncidentsByGame(
            @PathVariable String gameId,
            @RequestParam(required = false) String severity
    ) {
        try {
            List<Map<String, Object>> incidents;
            long count;

            if (severity != null && !severity.isBlank()) {
                incidents = incidentService.getIncidentsByGameAndSeverity(gameId, severity);
                count = incidentService.countIncidentsByGameAndSeverity(gameId, severity);
            } else {
                incidents = incidentService.getIncidentsByGame(gameId);
                count = incidentService.countIncidentsByGame(gameId);
            }

            return ResponseEntity.ok(Map.of(
                    "gameId", gameId,
                    "severity", severity != null ? severity : "ALL",
                    "incidentCount", count,
                    "incidents", incidents
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "ERROR",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Compter les incidents d'un jeu par sévérité
     * GET /platform/incidents/game/{gameId}/count?severity=CRITIQUE
     */
    @GetMapping("/game/{gameId}/count")
    public ResponseEntity<Map<String, Object>> countIncidents(
            @PathVariable String gameId,
            @RequestParam(required = false) String severity
    ) {
        try {
            long count;

            if (severity != null && !severity.isBlank()) {
                count = incidentService.countIncidentsByGameAndSeverity(gameId, severity);
            } else {
                count = incidentService.countIncidentsByGame(gameId);
            }

            return ResponseEntity.ok(Map.of(
                    "gameId", gameId,
                    "severity", severity != null ? severity : "ALL",
                    "incidentCount", count
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "ERROR",
                    "reason", e.getMessage()
            ));
        }
    }
}
