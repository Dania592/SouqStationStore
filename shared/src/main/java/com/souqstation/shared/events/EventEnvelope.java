package com.souqstation.shared.events;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record EventEnvelope(
        UUID eventId,
        String eventType,
        Instant occurredAt,
        int schemaVersion,
        Map<String, Object> payload
) {
    public static EventEnvelope of(String eventType, Map<String, Object> payload) {
        return new EventEnvelope(UUID.randomUUID(), eventType, Instant.now(), 1, payload);
    }
}
