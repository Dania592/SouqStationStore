package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ReviewRatingRepository extends JpaRepository<ReviewRatingEntity, String> {

    Optional<ReviewRatingEntity> findByReviewIdAndUserId(String reviewId, String userId);

    boolean existsByReviewIdAndUserId(String reviewId, String userId);

    long countByReviewIdAndIsHelpful(String reviewId, boolean isHelpful);
}
