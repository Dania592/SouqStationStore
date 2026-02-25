package com.souqstation.publisher.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ReceivedIncidentRepository extends JpaRepository<ReceivedIncidentEntity, String> {

    List<ReceivedIncidentEntity> findByGameIdOrderByReportedAtDesc(String gameId);

    List<ReceivedIncidentEntity> findByGameIdAndSeverity(String gameId, ReceivedIncidentEntity.IncidentSeverity severity);

    long countByGameId(String gameId);

    long countByGameIdAndSeverity(String gameId, ReceivedIncidentEntity.IncidentSeverity severity);
}
