package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.UserRegistered;
import com.souqstation.schemas.events.RedactorRegisteredEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;
@Component
public class PlatformUserEventProducer {

    private final KafkaTemplate<String, UserRegistered> userTemplate;
    private final KafkaTemplate<String, RedactorRegisteredEvent> redactorTemplate;

    private final String userTopic;
    private final String redactorTopic;

    public PlatformUserEventProducer(
            KafkaTemplate<String, UserRegistered> userTemplate,
            KafkaTemplate<String, RedactorRegisteredEvent> redactorTemplate,
            @Value("${souq.kafka.topics.platform.user:souq.platform.user.events}") String userTopic,
            @Value("${souq.kafka.topics.platform.redactor:souq.platform.redactor.events}") String redactorTopic
    ) {
        this.userTemplate = userTemplate;
        this.redactorTemplate = redactorTemplate;
        this.userTopic = userTopic;
        this.redactorTopic = redactorTopic;
    }

    public void publishUser(String key, UserRegistered event) {
        userTemplate.send(userTopic, key, event);
    }

    public void publishRedactor(String key, RedactorRegisteredEvent event) {
        redactorTemplate.send(redactorTopic, key, event);
    }
}