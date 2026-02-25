package com.souqstation.publisher.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReceivedReviewRepository extends JpaRepository<ReceivedReviewEntity, String> {

    List<ReceivedReviewEntity> findByGameIdOrderBySubmittedAtDesc(String gameId);

    long countByGameId(String gameId);

    List<ReceivedReviewEntity> findByGameIdAndNoteGreaterThanEqual(String gameId, int minNote);
}
