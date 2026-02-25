package com.souqstation.platform.messaging;

import com.souqstation.platform.persistence.ConsumedEventEntity;
import com.souqstation.platform.persistence.ConsumedEventRepository;
import com.souqstation.platform.service.CatalogService;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;
import com.souqstation.schemas.events.GamePublished;
import com.souqstation.schemas.events.PatchPublishedEvent;

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
    public void onEvent(ConsumerRecord<String, GamePublished> record, Acknowledgment ack) {

        GamePublished event = record.value();

        String eventId = event.getEventId();
        String eventType = event.getSchema().getName(); // => "GamePublished"
        Instant occurredAt = event.getOccurredAt();

        // 1) Idempotence
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            ack.acknowledge();
            return;
        }

        // 2) Save processed marker (+ metadata)
        consumedEventRepository.save(
                new ConsumedEventEntity(eventId, eventType, occurredAt, Instant.now()));

        // 3) Traitement métier : Ajouter au catalogue
        catalogService.addGameToCatalog(event);

        // 4) Log business
        System.out.println("[PLATFORM] processed key=" + record.key()
                + " type=" + eventType
                + " eventId=" + eventId
                + " gameId=" + event.getGameId()
                + " title=" + event.getName());

        ack.acknowledge();
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