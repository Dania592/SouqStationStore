package com.souqstation.platform.service;

import com.souqstation.platform.persistence.GamePlaySessionEntity;
import com.souqstation.platform.persistence.GamePlaySessionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class GameplayService {

    private final GamePlaySessionRepository sessionRepository;

    public GameplayService(GamePlaySessionRepository sessionRepository) {
        this.sessionRepository = sessionRepository;
    }

    @Transactional
    public GamePlaySessionEntity startSession(String userId, String gameId) {
        sessionRepository
                .findFirstByUserIdAndGameIdAndStatusOrderByStartedAtDesc(userId, gameId, GamePlaySessionEntity.Status.OPEN)
                .ifPresent(open -> { throw new IllegalStateException("Session already OPEN for this user and game."); });

        GamePlaySessionEntity session = new GamePlaySessionEntity(
                UUID.randomUUID().toString(),
                userId,
                gameId,
                Instant.now()
        );

        return sessionRepository.save(session);
    }

    @Transactional
    public GamePlaySessionEntity endSession(String userId, String gameId) {
        GamePlaySessionEntity open = sessionRepository
                .findFirstByUserIdAndGameIdAndStatusOrderByStartedAtDesc(userId, gameId, GamePlaySessionEntity.Status.OPEN)
                .orElseThrow(() -> new IllegalStateException("No OPEN session found for this user and game."));

        open.end(Instant.now());
        return sessionRepository.save(open);
    }

    @Transactional(readOnly = true)
    public long getTotalPlaytimeSeconds(String userId, String gameIdOrNull) {
        if (gameIdOrNull == null || gameIdOrNull.isBlank()) {
            return sessionRepository.totalPlaytimeByUser(userId);
        }
        return sessionRepository.totalPlaytimeByUserAndGame(userId, gameIdOrNull);
    }
}