package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GamePurchaseRepository extends JpaRepository<GamePurchaseEntity, String> {
    
    List<GamePurchaseEntity> findByUserId(String userId);
    
    List<GamePurchaseEntity> findByGameId(String gameId);
    
    boolean existsByUserIdAndGameId(String userId, String gameId);
    
    long countByGameId(String gameId);
}
