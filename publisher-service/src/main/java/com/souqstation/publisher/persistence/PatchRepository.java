package com.souqstation.publisher.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface PatchRepository extends JpaRepository<PatchEntity, String> {

    List<PatchEntity> findByGameId(String gameId);

    List<PatchEntity> findByGameIdOrderByReleasedAtDesc(String gameId);

    long countByGameId(String gameId);

    boolean existsByGameIdAndTargetVersion(String gameId, String targetVersion);
}
