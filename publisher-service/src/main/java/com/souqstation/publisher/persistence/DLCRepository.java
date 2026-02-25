package com.souqstation.publisher.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DLCRepository extends JpaRepository<DLCEntity, String> {

    List<DLCEntity> findByGameId(String gameId);

    List<DLCEntity> findByPublisherId(String publisherId);

    long countByGameId(String gameId);
}
