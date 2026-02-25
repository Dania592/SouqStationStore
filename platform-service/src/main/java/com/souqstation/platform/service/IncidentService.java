package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformIncidentEventProducer;
import com.souqstation.platform.persistence.*;
import com.souqstation.schemas.events.IncidentReportedEvent;
import com.souqstation.schemas.events.enums.IncidentSeverity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class IncidentService {

    private final IncidentRepository incidentRepository;
    private final UserRepository userRepository;
    private final GameCatalogRepository gameCatalogRepository;
    private final PlatformIncidentEventProducer producer;

    public IncidentService(
            IncidentRepository incidentRepository,
            UserRepository userRepository,
            GameCatalogRepository gameCatalogRepository,
            PlatformIncidentEventProducer producer
    ) {
        this.incidentRepository = incidentRepository;
        this.userRepository = userRepository;
        this.gameCatalogRepository = gameCatalogRepository;
        this.producer = producer;
    }

    @Transactional
    public IncidentReportedEvent reportIncident(
            String userId,
            String gameId,
            String severityStr,
            String description,
            String environment
    ) {
        Instant now = Instant.now();

        // 1) Vérifier que l'utilisateur existe
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        // 2) Vérifier que le jeu existe dans le catalogue
        if (!gameCatalogRepository.existsById(gameId)) {
            throw new IllegalArgumentException("Game not found in catalog: " + gameId);
        }

        // 3) Parser la sévérité
        IncidentEntity.IncidentSeverity severity;
        IncidentSeverity avroSeverity;
        try {
            severity = IncidentEntity.IncidentSeverity.valueOf(severityStr.toUpperCase());
            avroSeverity = IncidentSeverity.valueOf(severityStr.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid severity. Must be one of: CRITIQUE, HAUTE, NORMALE, BASSE");
        }

        // 4) Créer l'incident
        String incidentId = UUID.randomUUID().toString();
        IncidentEntity incident = new IncidentEntity(
                incidentId,
                gameId,
                userId,
                user.getDisplayName(),
                severity,
                description,
                environment,
                now
        );

        incidentRepository.save(incident);

        // 5) Créer l'événement Avro
        IncidentReportedEvent event = IncidentReportedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setIncidentId(incidentId)
                .setGameId(gameId)
                .setUserId(userId)
                .setPseudo(user.getDisplayName())
                .setSeverity(avroSeverity)
                .setDescription(description)
                .setEnvironment(environment)
                .setReportedAt(now)
                .build();

        // 6) Publier vers Kafka
        producer.publishIncident(gameId, event);

        return event;
    }

    public List<Map<String, Object>> getIncidentsByGame(String gameId) {
        List<IncidentEntity> incidents = incidentRepository.findByGameIdOrderByReportedAtDesc(gameId);
        return convertToMapList(incidents);
    }

    public List<Map<String, Object>> getIncidentsByGameAndSeverity(
            String gameId,
            String severityStr
    ) {
        IncidentEntity.IncidentSeverity severity;
        try {
            severity = IncidentEntity.IncidentSeverity.valueOf(severityStr.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid severity. Must be one of: CRITIQUE, HAUTE, NORMALE, BASSE");
        }

        List<IncidentEntity> incidents = incidentRepository.findByGameIdAndSeverity(gameId, severity);
        return convertToMapList(incidents);
    }

    public long countIncidentsByGame(String gameId) {
        return incidentRepository.countByGameId(gameId);
    }

    public long countIncidentsByGameAndSeverity(String gameId, String severityStr) {
        IncidentEntity.IncidentSeverity severity;
        try {
            severity = IncidentEntity.IncidentSeverity.valueOf(severityStr.toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Invalid severity");
        }

        return incidentRepository.countByGameIdAndSeverity(gameId, severity);
    }

    // Méthodes utilitaires
    private List<Map<String, Object>> convertToMapList(List<IncidentEntity> incidents) {
        return incidents.stream()
                .map(this::convertToMap)
                .collect(Collectors.toList());
    }

    private Map<String, Object> convertToMap(IncidentEntity incident) {
        return Map.of(
                "incidentId", incident.getIncidentId(),
                "gameId", incident.getGameId(),
                "userId", incident.getUserId(),
                "pseudo", incident.getPseudo(),
                "severity", incident.getSeverity().name(),
                "description", incident.getDescription(),
                "environment", incident.getEnvironment() != null ? incident.getEnvironment() : "",
                "reportedAt", incident.getReportedAt().toString()
        );
    }
}
