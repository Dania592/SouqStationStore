package com.souqstation.publisher.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "received_incidents")
public class ReceivedIncidentEntity {

    @Id
    @Column(name = "incident_id", nullable = false, updatable = false)
    private String incidentId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "pseudo", nullable = false)
    private String pseudo;

    @Column(name = "severity", nullable = false)
    @Enumerated(EnumType.STRING)
    private IncidentSeverity severity;

    @Column(name = "description", nullable = false, length = 2000)
    private String description;

    @Column(name = "environment", length = 500)
    private String environment;

    @Column(name = "reported_at", nullable = false)
    private Instant reportedAt;

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt;

    // Constructeur par défaut (requis par JPA)
    protected ReceivedIncidentEntity() {}

    // Constructeur complet
    public ReceivedIncidentEntity(
            String incidentId,
            String gameId,
            String userId,
            String pseudo,
            IncidentSeverity severity,
            String description,
            String environment,
            Instant reportedAt,
            Instant receivedAt
    ) {
        this.incidentId = incidentId;
        this.gameId = gameId;
        this.userId = userId;
        this.pseudo = pseudo;
        this.severity = severity;
        this.description = description;
        this.environment = environment;
        this.reportedAt = reportedAt;
        this.receivedAt = receivedAt;
    }

    // Enum pour la sévérité
    public enum IncidentSeverity {
        CRITIQUE,
        HAUTE,
        NORMALE,
        BASSE
    }

    // Getters
    public String getIncidentId() { return incidentId; }
    public String getGameId() { return gameId; }
    public String getUserId() { return userId; }
    public String getPseudo() { return pseudo; }
    public IncidentSeverity getSeverity() { return severity; }
    public String getDescription() { return description; }
    public String getEnvironment() { return environment; }
    public Instant getReportedAt() { return reportedAt; }
    public Instant getReceivedAt() { return receivedAt; }
}
