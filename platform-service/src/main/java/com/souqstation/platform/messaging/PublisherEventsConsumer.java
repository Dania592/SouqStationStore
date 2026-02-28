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
            CatalogService catalogService) {
        this.consumedEventRepository = consumedEventRepository;
        this.catalogService = catalogService;
    }

    @KafkaListener(topics = "${souq.topics.publisher}")
    public void onEvent(ConsumerRecord<String, Object> record, Acknowledgment ack) {

        Object value = record.value();
        if (value == null) {
            ack.acknowledge();
            return;
        }

        try {
            if (value instanceof GamePublished event) {
                handleGamePublished(record.key(), event);
            } else if (value instanceof DLCPublishedEvent event) {
                handleDlcPublished(record.key(), event);
            } else if (value instanceof PatchPublishedEvent event) {
                // si jamais tu envoies aussi les patchs sur le topic "publisher"
                handlePatchPublished(record.key(), event);
            } else {
                System.out.println("[PLATFORM] Unknown event type: " + value.getClass().getName()
                        + " topic=" + record.topic() + " offset=" + record.offset());
            }

            ack.acknowledge();
        } catch (Exception e) {
            // laisse l'error handler gérer (retry/DLT) si configuré
            throw e;
        }
    }

    private void handleGamePublished(String key, GamePublished event) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName(); // "GamePublished"
        Instant occurredAt = event.getOccurredAt();

        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            return;
        }

        consumedEventRepository.save(new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now()));
        catalogService.addGameToCatalog(event);

        System.out.println("[PLATFORM] processed key=" + key
                + " type=" + eventType
                + " eventId=" + eventId
                + " gameId=" + event.getGameId()
                + " title=" + event.getName());
    }

    private void handleDlcPublished(String key, DLCPublishedEvent event) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName(); // "DLCPublishedEvent"
        Instant occurredAt = event.getOccurredAt();

        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            return;
        }

        consumedEventRepository.save(new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now()));
        catalogService.addDlcToCatalog(event);

        System.out.println("[PLATFORM] processed DLC key=" + key
                + " eventId=" + eventId
                + " gameId=" + event.getGameId()
                + " dlcId=" + event.getDlcId()
                + " name=" + event.getName());
    }

    private void handlePatchPublished(String key, PatchPublishedEvent event) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName();
        Instant occurredAt = event.getOccurredAt();

        if (consumedEventRepository.existsById(eventId)) {
            return;
        }

        consumedEventRepository.save(new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now()));
        catalogService.updateGameVersion(event.getGameId(), event.getTargetVersion());

        System.out.println("[PLATFORM] processed patch key=" + key
                + " gameId=" + event.getGameId()
                + " -> newVersion=" + event.getTargetVersion());
    }

    @KafkaListener(topics = "${souq.topics.publisher-patch:souq.publisher.patch.events}")
    public void onPatchEvent(ConsumerRecord<String, PatchPublishedEvent> record, Acknowledgment ack) {
        PatchPublishedEvent event = record.value();
        String eventId = event.getEventId();

        if (consumedEventRepository.existsById(eventId)) {
            ack.acknowledge();
            return;
        }

        consumedEventRepository.save(
                new ConsumedEventEntity(eventId, event.getSchema().getName(), event.getOccurredAt(), Instant.now()));

        catalogService.updateGameVersion(event.getGameId(), event.getTargetVersion());

        System.out.println("[PLATFORM] processed patch for gameId=" + event.getGameId() + " -> newVersion="
                + event.getTargetVersion());
        ack.acknowledge();
    }
}