package com.souqstation.publisher.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DlcRepository extends JpaRepository<DlcEntity, String> {
    List<DlcEntity> findByGameId(String gameId);
    boolean existsByDlcId(String dlcId); // optionnel
}