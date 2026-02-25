package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface IncidentRepository extends JpaRepository<IncidentEntity, String> {

    List<IncidentEntity> findByGameId(String gameId);

    List<IncidentEntity> findByUserId(String userId);

    List<IncidentEntity> findByGameIdOrderByReportedAtDesc(String gameId);

    List<IncidentEntity> findByGameIdAndSeverity(String gameId, IncidentEntity.IncidentSeverity severity);

    long countByGameId(String gameId);

    long countByGameIdAndSeverity(String gameId, IncidentEntity.IncidentSeverity severity);
}
