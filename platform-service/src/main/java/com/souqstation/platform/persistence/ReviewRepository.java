package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReviewRepository extends JpaRepository<ReviewEntity, String> {

    List<ReviewEntity> findByGameId(String gameId);

    List<ReviewEntity> findByUserId(String userId);

    boolean existsByUserIdAndGameId(String userId, String gameId);

    long countByGameId(String gameId);

    List<ReviewEntity> findByGameIdOrderBySubmittedAtDesc(String gameId);

    List<ReviewEntity> findByUserIdOrderBySubmittedAtDesc(String userId);
}
