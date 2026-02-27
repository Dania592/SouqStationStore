package com.souqstation.platform.persistence;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    Page<ReviewEntity> findByGameIdAndNoteGreaterThanEqual(String gameId, int minNote, Pageable pageable);

    @Query("select avg(r.note) from ReviewEntity r where r.gameId = :gameId")
    Double avgNoteByGameId(@Param("gameId") String gameId);

}
