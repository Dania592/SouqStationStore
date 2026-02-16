package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.UserRegistered;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformUserEventProducer {

    private final KafkaTemplate<String, UserRegistered> kafkaTemplate;
    private final String topic;

    public PlatformUserEventProducer(
            KafkaTemplate<String, UserRegistered> kafkaTemplate,
            @Value("${souq.kafka.topics.platform:souq.platform.events}") String topic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.topic = topic;
    }

    public void publish(String key, UserRegistered event) {
        kafkaTemplate.send(topic, key, event);
    }
}