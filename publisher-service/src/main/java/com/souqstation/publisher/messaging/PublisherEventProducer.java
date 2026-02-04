package com.souqstation.publisher.messaging;

import com.souqstation.shared.events.EventEnvelope;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PublisherEventProducer {

    private final KafkaTemplate<String, EventEnvelope> kafkaTemplate;
    private final String topic;

    public PublisherEventProducer(
            KafkaTemplate<String, EventEnvelope> kafkaTemplate,
            @Value("${souq.topics.publisher}") String topic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.topic = topic;
    }

    public void publish(String key, EventEnvelope event) {
        kafkaTemplate.send(topic, key, event);
    }
}
