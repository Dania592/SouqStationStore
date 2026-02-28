package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface DlcRepository extends JpaRepository<DlcEntity, String> {
    List<DlcEntity> findByGameId(String gameId);
}
