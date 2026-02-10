package com.souqstation.notification.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.souqstation.notification.messaging.model.EventEnvelopeDto;
import com.souqstation.notification.messaging.model.UserNotificationDto;
import com.souqstation.notification.persistence.entity.ConsumedEventEntity;
import com.souqstation.notification.persistence.entity.NotificationEntity;
import com.souqstation.notification.persistence.repo.ConsumedEventRepository;
import com.souqstation.notification.persistence.repo.NotificationRepository;
import com.souqstation.notification.service.NotificationService;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Component
public class MultiEventConsumer {

    private final ObjectMapper objectMapper;
    private final ConsumedEventRepository consumedEventRepository;
    private final NotificationRepository notificationRepository;
    private final NotificationService notificationService;
    private final NotificationProducer notificationProducer;

    public MultiEventConsumer(
            ObjectMapper objectMapper,
            ConsumedEventRepository consumedEventRepository,
            NotificationRepository notificationRepository,
            NotificationService notificationService,
            NotificationProducer notificationProducer
    ) {
        this.objectMapper = objectMapper;
        this.consumedEventRepository = consumedEventRepository;
        this.notificationRepository = notificationRepository;
        this.notificationService = notificationService;
        this.notificationProducer = notificationProducer;
    }

    @KafkaListener(
            topics = {"${souq.kafka.topics.publisher}", "${souq.kafka.topics.platform}"},
            groupId = "notification-service"
    )
    public void onMessage(ConsumerRecord<String, String> record, Acknowledgment ack) {
        // Important: ACK seulement après succès total
        try {
            handle(record.value());
            ack.acknowledge();
        } catch (Exception e) {
            System.out.print("Erreur dans le multiEventConsumer onMessage :"+ e.getMessage());
        }
    }

    @Transactional
    public void handle(String rawJson) throws Exception {
        EventEnvelopeDto event = objectMapper.readValue(rawJson, EventEnvelopeDto.class);

        if (event.getEventId() == null || event.getEventId().isBlank()) {
            // message non conforme => on refuse pour debug (sinon tu "perds" des events)
            throw new IllegalArgumentException("Missing eventId in message");
        }

        // Idempotence: si déjà consommé, on ignore
        if (consumedEventRepository.existsById(event.getEventId())) {
            return;
        }

        // route
        List<UserNotificationDto> notifications = notificationService.route(event);

        // persist + publish
        for (UserNotificationDto n : notifications) {
            notificationRepository.save(new NotificationEntity(
                    n.getNotificationId(),
                    n.getUserId(),
                    n.getType(),
                    n.getMessage(),
                    n.getCreatedAt(),
                    n.getSourceEventId()
            ));
            notificationProducer.publish(n);
        }

        // marquer event consommé
        Instant occurredAt = event.getOccurredAt() != null ? event.getOccurredAt() : Instant.now();
        consumedEventRepository.save(new ConsumedEventEntity(event.getEventId(), event.getEventType(), occurredAt));
    }
}