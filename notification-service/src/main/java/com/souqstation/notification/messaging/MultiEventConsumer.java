package com.souqstation.notification.messaging;

import com.souqstation.notification.messaging.model.UserNotificationDto;
import com.souqstation.notification.persistence.entity.ConsumedEventEntity;
import com.souqstation.notification.persistence.entity.NotificationEntity;
import com.souqstation.notification.persistence.repo.ConsumedEventRepository;
import com.souqstation.notification.persistence.repo.NotificationRepository;
import com.souqstation.notification.service.NotificationService;
import com.souqstation.schemas.events.GamePurchasedEvent;
import com.souqstation.schemas.events.DLCPurchasedEvent;
import com.souqstation.schemas.events.ReviewSubmittedEvent;
import com.souqstation.schemas.events.IncidentReportedEvent;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Component
public class MultiEventConsumer {

    private final ConsumedEventRepository consumedEventRepository;
    private final NotificationRepository notificationRepository;
    private final NotificationService notificationService;

    public MultiEventConsumer(
            ConsumedEventRepository consumedEventRepository,
            NotificationRepository notificationRepository,
            NotificationService notificationService) {
        this.consumedEventRepository = consumedEventRepository;
        this.notificationRepository = notificationRepository;
        this.notificationService = notificationService;
    }

    @KafkaListener(topics = "${souq.topics.platform.purchase}", groupId = "notification-service")
    public void onPurchase(ConsumerRecord<String, Object> record, Acknowledgment ack) {
        try {
            Object value = record.value();
            if (value instanceof GamePurchasedEvent event) {
                process(event.getEventId().toString(), "GamePurchased", event.getOccurredAt(),
                        notificationService.handle(event));
            } else if (value instanceof DLCPurchasedEvent event) {
                process(event.getEventId().toString(), "DLCPurchased", event.getOccurredAt(),
                        notificationService.handle(event));
            }
            ack.acknowledge();
        } catch (Exception e) {
            System.err.println("Error consuming purchase event: " + e.getMessage());
        }
    }

    @KafkaListener(topics = "${souq.topics.platform.review}", groupId = "notification-service")
    public void onReview(ConsumerRecord<String, Object> record, Acknowledgment ack) {
        try {
            Object value = record.value();
            if (value instanceof ReviewSubmittedEvent event) {
                process(event.getEventId().toString(), "ReviewSubmitted", event.getOccurredAt(),
                        notificationService.handle(event));
            }
            ack.acknowledge();
        } catch (Exception e) {
            System.err.println("Error consuming review event: " + e.getMessage());
        }
    }

    @KafkaListener(topics = "${souq.topics.platform.incident}", groupId = "notification-service")
    public void onIncident(ConsumerRecord<String, Object> record, Acknowledgment ack) {
        try {
            Object value = record.value();
            if (value instanceof IncidentReportedEvent event) {
                process(event.getEventId().toString(), "IncidentReported", event.getOccurredAt(),
                        notificationService.handle(event));
            }
            ack.acknowledge();
        } catch (Exception e) {
            System.err.println("Error consuming incident event: " + e.getMessage());
        }
    }

    @Transactional
    public void process(String eventId, String eventType, java.time.Instant occurredAt,
            UserNotificationDto notification) {
        if (consumedEventRepository.existsById(eventId)) {
            return;
        }

        notificationRepository.save(new NotificationEntity(
                notification.getNotificationId(),
                notification.getUserId(),
                notification.getType(),
                notification.getMessage(),
                notification.getCreatedAt(),
                notification.getSourceEventId()));

        consumedEventRepository.save(
                new ConsumedEventEntity(eventId, eventType, occurredAt != null ? occurredAt : Instant.now()));
    }
}