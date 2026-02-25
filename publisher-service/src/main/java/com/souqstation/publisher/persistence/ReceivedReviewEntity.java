package com.souqstation.publisher.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "received_reviews")
public class ReceivedReviewEntity {

    @Id
    @Column(name = "review_id", nullable = false, updatable = false)
    private String reviewId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "pseudo", nullable = false)
    private String pseudo;

    @Column(name = "note", nullable = false)
    private int note;

    @Column(name = "description", length = 2000)
    private String description;

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt;

    // Constructeur par défaut (requis par JPA)
    protected ReceivedReviewEntity() {}

    // Constructeur complet
    public ReceivedReviewEntity(
            String reviewId,
            String gameId,
            String userId,
            String pseudo,
            int note,
            String description,
            Instant submittedAt,
            Instant receivedAt
    ) {
        this.reviewId = reviewId;
        this.gameId = gameId;
        this.userId = userId;
        this.pseudo = pseudo;
        this.note = note;
        this.description = description;
        this.submittedAt = submittedAt;
        this.receivedAt = receivedAt;
    }

    // Getters
    public String getReviewId() { return reviewId; }
    public String getGameId() { return gameId; }
    public String getUserId() { return userId; }
    public String getPseudo() { return pseudo; }
    public int getNote() { return note; }
    public String getDescription() { return description; }
    public Instant getSubmittedAt() { return submittedAt; }
    public Instant getReceivedAt() { return receivedAt; }
}
