package com.souqstation.platform.persistence;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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

    Page<IncidentEntity> findByGameId(String gameId, Pageable pageable);

    Page<IncidentEntity> findByGameIdAndSeverity(String gameId, IncidentEntity.IncidentSeverity severity, Pageable pageable);

}
