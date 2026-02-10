package com.souqstation.notification.persistence.repo;

import com.souqstation.notification.persistence.entity.NotificationEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<NotificationEntity, String> {
    List<NotificationEntity> findTop50ByUserIdOrderByCreatedAtDesc(String userId);
}