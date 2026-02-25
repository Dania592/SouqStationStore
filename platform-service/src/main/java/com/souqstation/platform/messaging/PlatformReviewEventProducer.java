package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.ReviewRatedEvent;
import com.souqstation.schemas.events.ReviewSubmittedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformReviewEventProducer {

    private final KafkaTemplate<String, ReviewSubmittedEvent> reviewSubmittedTemplate;
    private final KafkaTemplate<String, ReviewRatedEvent> reviewRatedTemplate;

    private final String reviewTopic;

    public PlatformReviewEventProducer(
            KafkaTemplate<String, ReviewSubmittedEvent> reviewSubmittedTemplate,
            KafkaTemplate<String, ReviewRatedEvent> reviewRatedTemplate,
            @Value("${souq.kafka.topics.platform.review}") String reviewTopic
    ) {
        this.reviewSubmittedTemplate = reviewSubmittedTemplate;
        this.reviewRatedTemplate = reviewRatedTemplate;
        this.reviewTopic = reviewTopic;
    }

    public void publishReviewSubmitted(String key, ReviewSubmittedEvent event) {
        reviewSubmittedTemplate.send(reviewTopic, key, event);
        System.out.println("[PRODUCER] ReviewSubmitted published: " + event.getReviewId());
    }

    public void publishReviewRated(String key, ReviewRatedEvent event) {
        reviewRatedTemplate.send(reviewTopic, key, event);
        System.out.println("[PRODUCER] ReviewRated published: " + event.getRatingId());
    }
}
