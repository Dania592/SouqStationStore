package com.souqstation.publisher.messaging;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.souqstation.shared.events.EventEnvelope;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PublisherEventProducer {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper;
    private final String topic;

    public PublisherEventProducer(
            KafkaTemplate<String, String> kafkaTemplate,
            ObjectMapper objectMapper,
            @Value("${souq.topics.publisher}") String topic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.objectMapper = objectMapper;
        this.topic = topic;
    }

    public void publish(String key, EventEnvelope event) {
        try {
            String json = objectMapper.writeValueAsString(event);
            kafkaTemplate.send(topic, key, json);
        } catch (Exception e) {
            throw new RuntimeException("Failed to serialize event", e);
        }
    }
}
