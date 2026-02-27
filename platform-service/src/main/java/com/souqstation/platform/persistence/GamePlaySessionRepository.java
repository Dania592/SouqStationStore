package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface GamePlaySessionRepository extends JpaRepository<GamePlaySessionEntity, String> {

    Optional<GamePlaySessionEntity> findFirstByUserIdAndGameIdAndStatusOrderByStartedAtDesc(
            String userId, String gameId, GamePlaySessionEntity.Status status
    );

    @Query("select coalesce(sum(s.durationSeconds), 0) from GamePlaySessionEntity s where s.userId = :userId")
    long totalPlaytimeByUser(@Param("userId") String userId);

    @Query("""
        select coalesce(sum(s.durationSeconds), 0)
        from GamePlaySessionEntity s
        where s.userId = :userId and s.gameId = :gameId
    """)
    long totalPlaytimeByUserAndGame(@Param("userId") String userId, @Param("gameId") String gameId);
}