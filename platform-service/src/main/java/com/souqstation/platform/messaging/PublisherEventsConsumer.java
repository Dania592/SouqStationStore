package com.souqstation.platform.messaging;

import com.souqstation.platform.persistence.ConsumedEventEntity;
import com.souqstation.platform.persistence.ConsumedEventRepository;
import com.souqstation.shared.events.EventEnvelope;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.UUID;

@Component
public class PublisherEventsConsumer {

    private final ConsumedEventRepository consumedEventRepository;

    public PublisherEventsConsumer(ConsumedEventRepository consumedEventRepository) {
        this.consumedEventRepository = consumedEventRepository;
    }

    @KafkaListener(topics = "${souq.topics.publisher}")
    public void onEvent(ConsumerRecord<String, EventEnvelope> record, Acknowledgment ack) {
        EventEnvelope event = record.value();
        UUID eventId = event.eventId();

        // 1) Idempotence check
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PLATFORM] duplicate ignored eventId=" + eventId);
            ack.acknowledge();
            return;
        }

        // 2) Mark as processed (simple version)
        consumedEventRepository.save(new ConsumedEventEntity(eventId, Instant.now()));

        // 3) Process business logic (V0: log)
        System.out.println("[PLATFORM] processed key=" + record.key()
                + " type=" + event.eventType()
                + " eventId=" + eventId
                + " payload=" + event.payload());

        // 4) ACK after success
        ack.acknowledge();
    }
}