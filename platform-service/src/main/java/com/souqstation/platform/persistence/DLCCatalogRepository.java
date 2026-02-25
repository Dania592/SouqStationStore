package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DLCCatalogRepository extends JpaRepository<DLCCatalogEntity, String> {

    List<DLCCatalogEntity> findByGameId(String gameId);

    List<DLCCatalogEntity> findByPublisherId(String publisherId);

    long countByGameId(String gameId);
}
