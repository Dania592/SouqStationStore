package com.souqstation.platform.service;

import com.souqstation.platform.persistence.IncidentEntity;
import com.souqstation.platform.persistence.IncidentRepository;
import com.souqstation.platform.persistence.ReviewEntity;
import com.souqstation.platform.persistence.ReviewRepository;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class FeedbackService {

    private final ReviewRepository reviewRepository;
    private final IncidentRepository incidentRepository;

    public FeedbackService(ReviewRepository reviewRepository, IncidentRepository incidentRepository) {
        this.reviewRepository = reviewRepository;
        this.incidentRepository = incidentRepository;
    }

    public Page<ReviewEntity> getReviews(String gameId, int minNote, Pageable pageable) {
        return reviewRepository.findByGameIdAndNoteGreaterThanEqual(gameId, minNote, pageable);
    }

    public Page<IncidentEntity> getIncidents(
            String gameId,
            IncidentEntity.IncidentSeverity severity,
            Pageable pageable
    ) {
        return (severity == null)
                ? incidentRepository.findByGameId(gameId, pageable)
                : incidentRepository.findByGameIdAndSeverity(gameId, severity, pageable);
    }

    public ReviewStats statsForGame(String gameId) {
        Double avg = reviewRepository.avgNoteByGameId(gameId);
        long count = reviewRepository.countByGameId(gameId);
        return new ReviewStats(gameId, avg == null ? 0.0 : avg, count);
    }

    // Petite classe interne pour la réponse stats (pas un DTO de mapping entity, juste un payload)
    public record ReviewStats(String gameId, double avgNote, long count) {}
}