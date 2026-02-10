package com.souqstation.notification.messaging.model;

import java.time.Instant;

public class UserNotificationDto {
    private String notificationId;
    private String userId;
    private String type;
    private String message;
    private Instant createdAt;
    private String sourceEventId;

    public UserNotificationDto() {}

    public UserNotificationDto(String notificationId, String userId, String type, String message, Instant createdAt, String sourceEventId) {
        this.notificationId = notificationId;
        this.userId = userId;
        this.type = type;
        this.message = message;
        this.createdAt = createdAt;
        this.sourceEventId = sourceEventId;
    }

    public String getNotificationId() { return notificationId; }
    public void setNotificationId(String notificationId) { this.notificationId = notificationId; }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public String getSourceEventId() { return sourceEventId; }
    public void setSourceEventId(String sourceEventId) { this.sourceEventId = sourceEventId; }
}