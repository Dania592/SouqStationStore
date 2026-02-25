package com.souqstation.publisher.messaging;

import com.souqstation.schemas.events.PatchPublishedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PublisherPatchEventProducer {

    private final KafkaTemplate<String, PatchPublishedEvent> patchTemplate;

    private final String topic;

    public PublisherPatchEventProducer(
            KafkaTemplate<String, PatchPublishedEvent> patchTemplate,
            @Value("${souq.kafka.topics.publisher.patch:souq.publisher.patch.events}") String topic) {
        this.patchTemplate = patchTemplate;
        this.topic = topic;
    }

    public void publishPatch(String key, PatchPublishedEvent event) {
        patchTemplate.send(topic, key, event);
        System.out.println("[PRODUCER] PatchPublished published: " + event.getPatchId());
    }
}
