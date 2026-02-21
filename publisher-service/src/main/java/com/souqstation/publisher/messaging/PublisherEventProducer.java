package com.souqstation.publisher.messaging;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;
import com.souqstation.schemas.events.GamePublished;
import org.apache.avro.generic.GenericRecord;

@Component
public class PublisherEventProducer {

    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final String topic;

    public PublisherEventProducer(
            KafkaTemplate<String, Object> kafkaTemplate,
            @Value("${souq.topics.publisher}") String topic
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.topic = topic;
    }

    public void publishGame(String key, GamePublished event) {
        kafkaTemplate.send(topic, key, event);
    }

    public void publishPatch(String key, GenericRecord event) {
        kafkaTemplate.send(topic, key, event);
    }

    public void publishDlc(String key, GenericRecord event) {
        kafkaTemplate.send(topic, key, event);
    }
}
