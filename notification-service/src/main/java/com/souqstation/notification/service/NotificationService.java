package com.souqstation.notification.service;

import com.souqstation.notification.messaging.model.EventEnvelopeDto;
import com.souqstation.notification.messaging.model.UserNotificationDto;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.*;

@Service
public class NotificationService {

    /**
     * MVP routing:
     * - ReviewSubmitted: notifier userId si présent dans payload (sinon ignore)
     * - IncidentReported: notifier userId si présent
     * - GamePurchased: confirmer achat au userId (si présent)
     * - GamePublished: ignore (ou notif userId si payload le contient)
     * - PatchPublished: ignore (pour la V0 sans projection d'acheteurs)
     *
     * Ensuite, on améliorera avec des "projections" (ownership).
     */
    public List<UserNotificationDto> route(EventEnvelopeDto event) {
        String eventType = safe(event.getEventType());
        Map<String, Object> p = event.getPayload() == null ? Map.of() : event.getPayload();

        return switch (eventType) {
            case "GamePurchased" -> {
                String userId = asString(p.get("userId"));
                String gameId = asString(p.get("gameId"));
                if (userId == null || gameId == null) yield List.of();
                yield List.of(build(event, userId, "PURCHASE_CONFIRMED",
                        "Achat confirmé pour le jeu " + gameId));
            }
            case "ReviewSubmitted" -> {
                // si ton payload contient un userId (auteur) ou publisherId, adapte ici
                String userId = asString(p.get("userId"));
                String gameId = asString(p.get("gameId"));
                if (userId == null || gameId == null) yield List.of();
                yield List.of(build(event, userId, "REVIEW_RECEIVED",
                        "Merci pour ton avis sur " + gameId));
            }
            case "IncidentReported" -> {
                String userId = asString(p.get("userId"));
                String gameId = asString(p.get("gameId"));
                if (userId == null || gameId == null) yield List.of();
                yield List.of(build(event, userId, "INCIDENT_RECEIVED",
                        "Incident reçu pour " + gameId + ". On revient vers toi rapidement."));
            }
            default -> List.of();
        };
    }

    private UserNotificationDto build(EventEnvelopeDto event, String userId, String type, String message) {
        return new UserNotificationDto(
                UUID.randomUUID().toString(),
                userId,
                type,
                message,
                Instant.now(),
                event.getEventId()
        );
    }

    private static String safe(String s) {
        return s == null ? "" : s.trim();
    }

    private static String asString(Object o) {
        if (o == null) return null;
        String s = String.valueOf(o).trim();
        return s.isEmpty() ? null : s;
    }
}