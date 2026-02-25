package com.souqstation.platform.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "reviews")
public class ReviewEntity {

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
    private int note;  // 0-10

    @Column(name = "description", length = 2000)
    private String description;

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;

    @Column(name = "helpful_count", nullable = false)
    private int helpfulCount = 0;

    @Column(name = "unhelpful_count", nullable = false)
    private int unhelpfulCount = 0;

    // Constructeur par défaut (requis par JPA)
    protected ReviewEntity() {}

    // Constructeur complet
    public ReviewEntity(
            String reviewId,
            String gameId,
            String userId,
            String pseudo,
            int note,
            String description,
            Instant submittedAt
    ) {
        this.reviewId = reviewId;
        this.gameId = gameId;
        this.userId = userId;
        this.pseudo = pseudo;
        this.note = note;
        this.description = description;
        this.submittedAt = submittedAt;
        this.helpfulCount = 0;
        this.unhelpfulCount = 0;
    }

    // Méthodes utilitaires
    public void incrementHelpful() {
        this.helpfulCount++;
    }

    public void decrementHelpful() {
        if (this.helpfulCount > 0) {
            this.helpfulCount--;
        }
    }

    public void incrementUnhelpful() {
        this.unhelpfulCount++;
    }

    public void decrementUnhelpful() {
        if (this.unhelpfulCount > 0) {
            this.unhelpfulCount--;
        }
    }

    // Getters
    public String getReviewId() { return reviewId; }
    public String getGameId() { return gameId; }
    public String getUserId() { return userId; }
    public String getPseudo() { return pseudo; }
    public int getNote() { return note; }
    public String getDescription() { return description; }
    public Instant getSubmittedAt() { return submittedAt; }
    public int getHelpfulCount() { return helpfulCount; }
    public int getUnhelpfulCount() { return unhelpfulCount; }
}
