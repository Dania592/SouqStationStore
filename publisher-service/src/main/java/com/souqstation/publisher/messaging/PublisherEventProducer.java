package com.souqstation.publisher.messaging;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;
import com.souqstation.schemas.events.GamePublished;

@Component
public class PublisherEventProducer {

    private final KafkaTemplate<String, GamePublished> kafkaTemplate;
    private final String topic;

    public PublisherEventProducer(
            KafkaTemplate<String, GamePublished> kafkaTemplate,
            @Value("${souq.topics.publisher}") String topic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.topic = topic;
    }

    public void publish(String key, GamePublished  event) {
        kafkaTemplate.send(topic, key, event);
    }
}
