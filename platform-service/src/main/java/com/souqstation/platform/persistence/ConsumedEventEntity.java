package com.souqstation.platform.persistence;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "consumed_events")
public class ConsumedEventEntity {

    @Id
    private UUID eventId;

    private Instant consumedAt;

    protected ConsumedEventEntity() {}

    public ConsumedEventEntity(UUID eventId, Instant consumedAt) {
        this.eventId = eventId;
        this.consumedAt = consumedAt;
    }

    public UUID getEventId() { return eventId; }
    public Instant getConsumedAt() { return consumedAt; }
}