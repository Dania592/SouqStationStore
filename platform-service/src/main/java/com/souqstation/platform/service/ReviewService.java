package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformReviewEventProducer;
import com.souqstation.platform.persistence.*;
import com.souqstation.schemas.events.ReviewRatedEvent;
import com.souqstation.schemas.events.ReviewSubmittedEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final ReviewRatingRepository reviewRatingRepository;
    private final UserRepository userRepository;
    private final GamePurchaseRepository gamePurchaseRepository;
    private final PlatformReviewEventProducer producer;
    private final GameplayService gameplayService;
    private final GameCatalogRepository gameCatalogRepository;
    private static final long MIN_REVIEW_PLAYTIME_SECONDS = 3L; // 3 minutes de jeu minimum

    public ReviewService(
            ReviewRepository reviewRepository,
            ReviewRatingRepository reviewRatingRepository,
            UserRepository userRepository,
            GamePurchaseRepository gamePurchaseRepository,
            PlatformReviewEventProducer producer,
            GameplayService gameplayService,
            GameCatalogRepository gameCatalogRepository) {
        this.reviewRepository = reviewRepository;
        this.reviewRatingRepository = reviewRatingRepository;
        this.userRepository = userRepository;
        this.gamePurchaseRepository = gamePurchaseRepository;
        this.producer = producer;
        this.gameplayService = gameplayService;
        this.gameCatalogRepository = gameCatalogRepository;
    }

    @Transactional
    public ReviewSubmittedEvent submitReview(
            String userId,
            String gameId,
            int note,
            String description) {
        Instant now = Instant.now();

        // 1) Vérifier que l'utilisateur existe
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        // 2) Vérifier que l'utilisateur possède le jeu
        if (!gamePurchaseRepository.existsByUserIdAndGameId(userId, gameId)) {
            throw new IllegalArgumentException("User must own the game to submit a review: " + gameId);
        }

        // 3) Vérifier que l'utilisateur n'a pas déjà soumis une review
        if (reviewRepository.existsByUserIdAndGameId(userId, gameId)) {
            throw new IllegalArgumentException("User has already reviewed this game: " + gameId);
        }

        // 4) Valider la note
        if (note < 0 || note > 10) {
            throw new IllegalArgumentException("Rating must be between 0 and 10");
        }

        // 5) Temps minimum de jeu
        long playedSeconds = gameplayService.getTotalPlaytimeSeconds(userId, gameId);
        if (playedSeconds < MIN_REVIEW_PLAYTIME_SECONDS) {
            long remaining = MIN_REVIEW_PLAYTIME_SECONDS - playedSeconds;
            throw new IllegalArgumentException(
                    "You must play at least 3 seconds before reviewing. Remaining: " + remaining + "(s).");
        }

        // 6) Créer la review
        String reviewId = UUID.randomUUID().toString();
        ReviewEntity review = new ReviewEntity(
                reviewId,
                gameId,
                userId,
                user.getDisplayName(),
                note,
                description,
                now);

        reviewRepository.save(review);

        // 7) Créer l'événement Avro
        ReviewSubmittedEvent event = ReviewSubmittedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setReviewId(reviewId)
                .setGameId(gameId)
                .setUserId(userId)
                .setPseudo(user.getDisplayName())
                .setNote(note)
                .setDescription(description)
                .setSubmittedAt(now)
                .build();

        // 8) Publier vers Kafka
        producer.publishReviewSubmitted(gameId, event);

        // 9) Appliquer une promotion si beaucoup d'avis positifs
        applyPromotionIfEligible(gameId);

        return event;
    }

    private void applyPromotionIfEligible(String gameId) {
        List<ReviewEntity> gameReviews = reviewRepository.findByGameIdOrderBySubmittedAtDesc(gameId);
        long totalReviews = gameReviews.size();

        // Par exemple: si au moins 5 avis et moyenne >= 8/10
        if (totalReviews >= 5) {
            double avgNote = gameReviews.stream()
                    .mapToDouble(ReviewEntity::getNote)
                    .average()
                    .orElse(0.0);

            if (avgNote >= 8.0) {
                gameCatalogRepository.findById(gameId).ifPresent(game -> {
                    // S'assurer qu'on n'a pas déjà appliqué la promo (on vérifie le
                    // titre/description)
                    if (game.getPrice() != null && game.getPrice() > 0 &&
                            (game.getDescription() == null || !game.getDescription().contains("[PROMOTION]"))) {

                        double newPrice = Math.round(game.getPrice() * 0.9 * 100.0) / 100.0; // 10% de réduction
                        game.setPrice(newPrice);
                        game.setDescription(
                                "[PROMOTION] " + (game.getDescription() != null ? game.getDescription() : ""));
                        gameCatalogRepository.save(game);

                        System.out.println("[PROMO] 10% discount applied to " + gameId
                                + " due to excellent reviews! New price: " + newPrice);
                    }
                });
            }
        }
    }

    @Transactional
    public ReviewRatedEvent rateReview(
            String reviewId,
            String userId,
            boolean isHelpful) {
        Instant now = Instant.now();

        // 1) Vérifier que la review existe
        ReviewEntity review = reviewRepository.findById(reviewId)
                .orElseThrow(() -> new IllegalArgumentException("Review not found: " + reviewId));

        // 2) Vérifier que l'utilisateur existe
        if (!userRepository.existsById(userId)) {
            throw new IllegalArgumentException("User not found: " + userId);
        }

        // 3) Vérifier si l'utilisateur a déjà noté cette review
        String ratingId;
        ReviewRatingEntity rating = reviewRatingRepository
                .findByReviewIdAndUserId(reviewId, userId)
                .orElse(null);

        if (rating != null) {
            // Changer de vote : décrémenter l'ancien, incrémenter le nouveau
            if (rating.isHelpful() != isHelpful) {
                if (rating.isHelpful()) {
                    review.decrementHelpful();
                    review.incrementUnhelpful();
                } else {
                    review.decrementUnhelpful();
                    review.incrementHelpful();
                }
                rating.setHelpful(isHelpful);
                reviewRatingRepository.save(rating);
                ratingId = rating.getRatingId();
            } else {
                // Même vote, pas de changement
                ratingId = rating.getRatingId();
            }
        } else {
            // Nouveau vote
            ratingId = UUID.randomUUID().toString();
            rating = new ReviewRatingEntity(ratingId, reviewId, userId, isHelpful, now);
            reviewRatingRepository.save(rating);

            if (isHelpful) {
                review.incrementHelpful();
            } else {
                review.incrementUnhelpful();
            }
        }

        reviewRepository.save(review);

        // 4) Créer l'événement Avro
        ReviewRatedEvent event = ReviewRatedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setRatingId(ratingId)
                .setReviewId(reviewId)
                .setUserId(userId)
                .setIsHelpful(isHelpful)
                .setRatedAt(now)
                .build();

        // 5) Publier vers Kafka
        producer.publishReviewRated(reviewId, event);

        return event;
    }

    public List<Map<String, Object>> getReviewsByGame(String gameId) {
        List<ReviewEntity> reviews = reviewRepository.findByGameIdOrderBySubmittedAtDesc(gameId);
        return convertToMapList(reviews);
    }

    public List<Map<String, Object>> getReviewsByUser(String userId) {
        List<ReviewEntity> reviews = reviewRepository.findByUserIdOrderBySubmittedAtDesc(userId);
        return convertToMapList(reviews);
    }

    public long countReviewsByGame(String gameId) {
        return reviewRepository.countByGameId(gameId);
    }

    // Méthodes utilitaires
    private List<Map<String, Object>> convertToMapList(List<ReviewEntity> reviews) {
        return reviews.stream()
                .map(this::convertToMap)
                .collect(Collectors.toList());
    }

    private Map<String, Object> convertToMap(ReviewEntity review) {
        return Map.of(
                "reviewId", review.getReviewId(),
                "gameId", review.getGameId(),
                "userId", review.getUserId(),
                "pseudo", review.getPseudo(),
                "note", review.getNote(),
                "description", review.getDescription() != null ? review.getDescription() : "",
                "submittedAt", review.getSubmittedAt().toString(),
                "helpfulCount", review.getHelpfulCount(),
                "unhelpfulCount", review.getUnhelpfulCount());
    }
}
