package com.souqstation.notification.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.souqstation.notification.messaging.model.UserNotificationDto;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class NotificationProducer {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;
    private final String notificationTopic;

    public NotificationProducer(
            KafkaTemplate<String, String> kafkaTemplate,
            ObjectMapper objectMapper,
            @Value("${souq.kafka.topics.notification}") String notificationTopic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
        this.notificationTopic = notificationTopic;
    }

    public void publish(UserNotificationDto notification) {
        try {
            String key = notification.getUserId();
            String value = objectMapper.writeValueAsString(notification);
            kafkaTemplate.send(notificationTopic, key, value);
        } catch (Exception e) {
            throw new RuntimeException("Failed to publish notification", e);
        }
    }
}