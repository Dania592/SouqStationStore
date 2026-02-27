package com.souqstation.platform.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
        name = "game_play_sessions",
        indexes = {
                @Index(name = "idx_gps_user_game_status", columnList = "userId, gameId, status"),
                @Index(name = "idx_gps_user", columnList = "userId"),
                @Index(name = "idx_gps_user_game", columnList = "userId, gameId")
        }
)
public class GamePlaySessionEntity {

    @Id
    @Column(name = "session_id", nullable = false, updatable = false)
    private String sessionId;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "ended_at")
    private Instant endedAt;

    @Column(name = "duration_seconds")
    private Long durationSeconds;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private Status status;

    protected GamePlaySessionEntity() {}

    public GamePlaySessionEntity(String sessionId, String userId, String gameId, Instant startedAt) {
        this.sessionId = sessionId;
        this.userId = userId;
        this.gameId = gameId;
        this.startedAt = startedAt;
        this.status = Status.OPEN;
    }

    public void end(Instant endedAt) {
        this.endedAt = endedAt;
        long seconds = Math.max(0, endedAt.getEpochSecond() - startedAt.getEpochSecond());
        this.durationSeconds = seconds;
        this.status = Status.CLOSED;
    }

    public enum Status { OPEN, CLOSED }

    public String getSessionId() { return sessionId; }
    public String getUserId() { return userId; }
    public String getGameId() { return gameId; }
    public Instant getStartedAt() { return startedAt; }
    public Instant getEndedAt() { return endedAt; }
    public Long getDurationSeconds() { return durationSeconds; }
    public Status getStatus() { return status; }
}