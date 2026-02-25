package com.souqstation.platform.messaging;

import com.souqstation.platform.persistence.ConsumedEventEntity;
import com.souqstation.platform.persistence.ConsumedEventRepository;
import com.souqstation.platform.service.CatalogService;
import com.souqstation.schemas.events.DLCPublishedEvent;
import com.souqstation.schemas.events.GamePublished;
import com.souqstation.schemas.events.PatchPublishedEvent;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
public class PublisherEventsConsumer {

    private final ConsumedEventRepository consumedEventRepository;
    private final CatalogService catalogService;

    public PublisherEventsConsumer(
            ConsumedEventRepository consumedEventRepository,
            CatalogService catalogService
    ) {
        this.consumedEventRepository = consumedEventRepository;
        this.catalogService = catalogService;
    }

    @KafkaListener(topics = "${souq.topics.publisher}")
    public void onEvent(ConsumerRecord<String, Object> record, Acknowledgment ack) {

        Object value = record.value();

        // Déterminer le type d'événement
        if (value instanceof GamePublished) {
            handleGamePublished(record.key(), (GamePublished) value);
        } else if (value instanceof DLCPublishedEvent) {
            handleDLCPublished(record.key(), (DLCPublishedEvent) value);
        } else if (value instanceof PatchPublishedEvent) {
            handlePatchPublished(record.key(), (PatchPublishedEvent) value);
        } else {
            System.out.println("[PLATFORM] Unknown event type: " + value.getClass().getSimpleName());
        }

        ack.acknowledge();
    }

    private void handleGamePublished(String key, GamePublished event) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName();
        Instant occurredAt = event.getOccurredAt();

        // 1) Idempotence
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            return;
        }

        // 2) Save processed marker
        consumedEventRepository.save(
                new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now())
        );

        // 3) Traitement métier : Ajouter au catalogue
        catalogService.addGameToCatalog(event);

        // 4) Log
        System.out.println("[PLATFORM] GamePublished processed: " + event.getGameId() + " - " + event.getName());
    }

    private void handleDLCPublished(String key, DLCPublishedEvent event) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName();
        Instant occurredAt = event.getOccurredAt();

        // 1) Idempotence
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            return;
        }

        // 2) Save processed marker
        consumedEventRepository.save(
                new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now())
        );

        // 3) Traitement métier : Ajouter DLC au catalogue
        catalogService.addDLCToCatalog(event);

        // 4) Log
        System.out.println("[PLATFORM] DLCPublished processed: " + event.getDlcId() + " for game " + event.getGameId());
    }

    private void handlePatchPublished(String key, PatchPublishedEvent event) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName();
        Instant occurredAt = event.getOccurredAt();

        // 1) Idempotence
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            return;
        }

        // 2) Save processed marker
        consumedEventRepository.save(
                new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now())
        );

        // 3) Traitement métier : Mettre à jour la version du jeu dans le catalogue
        catalogService.updateGameVersion(event.getGameId(), event.getTargetVersion());

        // 4) Log
        System.out.println("[PLATFORM] PatchPublished processed: " + event.getPatchId() 
                + " updated game " + event.getGameId() + " to version " + event.getTargetVersion());
    }
}