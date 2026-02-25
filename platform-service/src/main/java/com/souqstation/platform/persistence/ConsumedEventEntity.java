package com.souqstation.platform.persistence;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "consumed_events")
public class ConsumedEventEntity {

    @Id
    private String eventId;

    private String eventType;

    private Instant occurredAt;

    private Instant consumedAt;

    // Si tu as ajouté payload jsonb :
    // private String payload;

    protected ConsumedEventEntity() {}

    public ConsumedEventEntity(String eventId, String eventType, Instant occurredAt, Instant consumedAt) {
        this.eventId = eventId;
        this.eventType = eventType;
        this.occurredAt = occurredAt;
        this.consumedAt = consumedAt;
    }

    public String getEventId() { return eventId; }
    public String getEventType() { return eventType; }
    public Instant getOccurredAt() { return occurredAt; }
    public Instant getConsumedAt() { return consumedAt; }
}