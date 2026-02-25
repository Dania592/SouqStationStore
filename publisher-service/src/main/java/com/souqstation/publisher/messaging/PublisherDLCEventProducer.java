package com.souqstation.publisher.messaging;

import com.souqstation.schemas.events.DLCPublishedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PublisherDLCEventProducer {

    private final KafkaTemplate<String, DLCPublishedEvent> dlcTemplate;

    private final String topic;

    public PublisherDLCEventProducer(
            KafkaTemplate<String, DLCPublishedEvent> dlcTemplate,
            @Value("${souq.topics.publisher}") String topic
    ) {
        this.dlcTemplate = dlcTemplate;
        this.topic = topic;
    }

    public void publishDLC(String key, DLCPublishedEvent event) {
        dlcTemplate.send(topic, key, event);
        System.out.println("[PRODUCER] DLCPublished published: " + event.getDlcId());
    }
}
