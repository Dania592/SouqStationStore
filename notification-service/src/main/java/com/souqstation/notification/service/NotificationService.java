package com.souqstation.notification.service;

import com.souqstation.notification.messaging.model.UserNotificationDto;
import com.souqstation.schemas.events.GamePurchasedEvent;
import com.souqstation.schemas.events.DLCPurchasedEvent;
import com.souqstation.schemas.events.ReviewSubmittedEvent;
import com.souqstation.schemas.events.IncidentReportedEvent;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

@Service
public class NotificationService {

    public UserNotificationDto handle(GamePurchasedEvent event) {
        return build(event.getEventId().toString(), event.getUserId().toString(), "PURCHASE_CONFIRMATION",
                "Achat confirmé pour le jeu " + event.getGameId());
    }

    public UserNotificationDto handle(DLCPurchasedEvent event) {
        return build(event.getEventId().toString(), event.getUserId().toString(), "DLC_AVAILABLE",
                "Achat confirmé pour le DLC " + event.getDlcId());
    }

    public UserNotificationDto handle(ReviewSubmittedEvent event) {
        return build(event.getEventId().toString(), event.getUserId().toString(), "REVIEW_RESPONSE",
                "Merci pour ton avis sur le jeu " + event.getGameId());
    }

    public UserNotificationDto handle(IncidentReportedEvent event) {
        return build(event.getEventId().toString(), event.getUserId().toString(), "INCIDENT_UPDATE",
                "Incident bien reçu pour le jeu " + event.getGameId() + ". Nous reviendrons vers toi rapidement.");
    }

    private UserNotificationDto build(String eventId, String userId, String type, String message) {
        return new UserNotificationDto(
                UUID.randomUUID().toString(),
                userId,
                type,
                message,
                Instant.now(),
                eventId);
    }
}