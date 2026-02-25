package com.souqstation.platform.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(
    name = "review_ratings",
    uniqueConstraints = @UniqueConstraint(columnNames = {"review_id", "user_id"})
)
public class ReviewRatingEntity {

    @Id
    @Column(name = "rating_id", nullable = false, updatable = false)
    private String ratingId;

    @Column(name = "review_id", nullable = false)
    private String reviewId;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "is_helpful", nullable = false)
    private boolean isHelpful;  // true = utile, false = pas utile

    @Column(name = "rated_at", nullable = false)
    private Instant ratedAt;

    // Constructeur par défaut (requis par JPA)
    protected ReviewRatingEntity() {}

    // Constructeur complet
    public ReviewRatingEntity(
            String ratingId,
            String reviewId,
            String userId,
            boolean isHelpful,
            Instant ratedAt
    ) {
        this.ratingId = ratingId;
        this.reviewId = reviewId;
        this.userId = userId;
        this.isHelpful = isHelpful;
        this.ratedAt = ratedAt;
    }

    // Getters
    public String getRatingId() { return ratingId; }
    public String getReviewId() { return reviewId; }
    public String getUserId() { return userId; }
    public boolean isHelpful() { return isHelpful; }
    public Instant getRatedAt() { return ratedAt; }

    // Setter pour modification
    public void setHelpful(boolean helpful) {
        this.isHelpful = helpful;
    }
}
