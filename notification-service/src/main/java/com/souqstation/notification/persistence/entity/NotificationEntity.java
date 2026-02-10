package com.souqstation.notification.persistence.entity;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "notifications", indexes = {
        @Index(name = "idx_notifications_user", columnList = "user_id")
})
public class NotificationEntity {

    @Id
    @Column(name = "notification_id", nullable = false, length = 64)
    private String notificationId;

    @Column(name = "user_id", nullable = false, length = 64)
    private String userId;

    @Column(name = "type", nullable = false, length = 64)
    private String type;

    @Column(name = "message", nullable = false, length = 500)
    private String message;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "source_event_id", nullable = false, length = 64)
    private String sourceEventId;

    protected NotificationEntity() {}

    public NotificationEntity(String notificationId, String userId, String type, String message, Instant createdAt, String sourceEventId) {
        this.notificationId = notificationId;
        this.userId = userId;
        this.type = type;
        this.message = message;
        this.createdAt = createdAt;
        this.sourceEventId = sourceEventId;
    }

    public String getNotificationId() { return notificationId; }
    public String getUserId() { return userId; }
    public String getType() { return type; }
    public String getMessage() { return message; }
    public Instant getCreatedAt() { return createdAt; }
    public String getSourceEventId() { return sourceEventId; }
}