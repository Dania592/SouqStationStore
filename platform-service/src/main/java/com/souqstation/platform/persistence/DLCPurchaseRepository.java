package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DLCPurchaseRepository extends JpaRepository<DLCPurchaseEntity, String> {

    List<DLCPurchaseEntity> findByUserId(String userId);

    boolean existsByUserIdAndDlcId(String userId, String dlcId);

    long countByDlcId(String dlcId);
}
