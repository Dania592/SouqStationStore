package com.souqstation.platform.api;

import com.souqstation.platform.persistence.IncidentEntity;
import com.souqstation.platform.persistence.ReviewEntity;
import com.souqstation.platform.service.FeedbackService;
import org.springframework.data.domain.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/platform/feedback")
public class FeedbackController {

    private final FeedbackService feedbackService;

    public FeedbackController(FeedbackService feedbackService) {
        this.feedbackService = feedbackService;
    }

    @GetMapping("/reviews")
    public Page<ReviewEntity> getReviews(
            @RequestParam String gameId,
            @RequestParam(defaultValue = "0") int minNote,
            @RequestParam(defaultValue = "desc") String sort,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Sort s = "asc".equalsIgnoreCase(sort)
                ? Sort.by("submittedAt").ascending()
                : Sort.by("submittedAt").descending();

        Pageable pageable = PageRequest.of(page, size, s);
        return feedbackService.getReviews(gameId, minNote, pageable);
    }

    @GetMapping("/incidents")
    public Page<IncidentEntity> getIncidents(
            @RequestParam String gameId,
            @RequestParam(required = false) IncidentEntity.IncidentSeverity severity,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Pageable pageable = PageRequest.of(page, size, Sort.by("reportedAt").descending());
        return feedbackService.getIncidents(gameId, severity, pageable);
    }

    @GetMapping("/reviews/{gameId}/stats")
    public FeedbackService.ReviewStats getReviewStats(@PathVariable String gameId) {
        return feedbackService.statsForGame(gameId);
    }
}