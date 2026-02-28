package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface DlcPurchaseRepository extends JpaRepository<DlcPurchaseEntity, String> {
    List<DlcPurchaseEntity> findByUserId(String userId);

    boolean existsByUserIdAndDlcId(String userId, String dlcId);
}
