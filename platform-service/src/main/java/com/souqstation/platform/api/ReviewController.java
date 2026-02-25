package com.souqstation.platform.api;

import com.souqstation.platform.service.ReviewService;
import com.souqstation.schemas.events.ReviewRatedEvent;
import com.souqstation.schemas.events.ReviewSubmittedEvent;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/platform/reviews")
public class ReviewController {

    private final ReviewService reviewService;

    public ReviewController(ReviewService reviewService) {
        this.reviewService = reviewService;
    }

    /**
     * Soumettre une review pour un jeu
     * POST /platform/reviews/submit?userId=U1&gameId=G1&note=8&description=...
     */
    @PostMapping("/submit")
    public ResponseEntity<Map<String, Object>> submitReview(
            @RequestParam String userId,
            @RequestParam String gameId,
            @RequestParam int note,
            @RequestParam(required = false) String description
    ) {
        try {
            ReviewSubmittedEvent event = reviewService.submitReview(userId, gameId, note, description);

            return ResponseEntity.ok(Map.of(
                    "status", "REVIEW_SUBMITTED",
                    "eventId", event.getEventId(),
                    "reviewId", event.getReviewId(),
                    "gameId", event.getGameId(),
                    "userId", event.getUserId(),
                    "note", event.getNote(),
                    "submittedAt", event.getSubmittedAt().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "REVIEW_REJECTED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Noter une review comme utile ou pas utile
     * POST /platform/reviews/{reviewId}/rate?userId=U2&isHelpful=true
     */
    @PostMapping("/{reviewId}/rate")
    public ResponseEntity<Map<String, Object>> rateReview(
            @PathVariable String reviewId,
            @RequestParam String userId,
            @RequestParam boolean isHelpful
    ) {
        try {
            ReviewRatedEvent event = reviewService.rateReview(reviewId, userId, isHelpful);

            return ResponseEntity.ok(Map.of(
                    "status", "REVIEW_RATED",
                    "eventId", event.getEventId(),
                    "ratingId", event.getRatingId(),
                    "reviewId", event.getReviewId(),
                    "userId", event.getUserId(),
                    "isHelpful", event.getIsHelpful(),
                    "ratedAt", event.getRatedAt().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "RATING_REJECTED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Récupérer toutes les reviews d'un jeu
     * GET /platform/reviews/game/{gameId}
     */
    @GetMapping("/game/{gameId}")
    public ResponseEntity<Map<String, Object>> getReviewsByGame(@PathVariable String gameId) {
        List<Map<String, Object>> reviews = reviewService.getReviewsByGame(gameId);
        long count = reviewService.countReviewsByGame(gameId);

        return ResponseEntity.ok(Map.of(
                "gameId", gameId,
                "reviewCount", count,
                "reviews", reviews
        ));
    }

    /**
     * Récupérer toutes les reviews d'un utilisateur
     * GET /platform/reviews/user/{userId}
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<Map<String, Object>> getReviewsByUser(@PathVariable String userId) {
        List<Map<String, Object>> reviews = reviewService.getReviewsByUser(userId);

        return ResponseEntity.ok(Map.of(
                "userId", userId,
                "reviewCount", reviews.size(),
                "reviews", reviews
        ));
    }
}
