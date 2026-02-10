package com.souqstation.notification.persistence.repo;

import com.souqstation.notification.persistence.entity.ConsumedEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConsumedEventRepository extends JpaRepository<ConsumedEventEntity, String> {
}