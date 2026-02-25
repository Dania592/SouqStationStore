package com.souqstation.publisher.messaging;

import com.souqstation.publisher.persistence.ConsumedEventEntity;
import com.souqstation.publisher.persistence.ConsumedEventRepository;
import com.souqstation.publisher.persistence.ReceivedReviewEntity;
import com.souqstation.publisher.persistence.ReceivedReviewRepository;
import com.souqstation.schemas.events.ReviewSubmittedEvent;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Component
public class ReviewConsumer {

    private final ReceivedReviewRepository reviewRepository;
    private final ConsumedEventRepository consumedEventRepository;

    public ReviewConsumer(
            ReceivedReviewRepository reviewRepository,
            ConsumedEventRepository consumedEventRepository
    ) {
        this.reviewRepository = reviewRepository;
        this.consumedEventRepository = consumedEventRepository;
    }

    @KafkaListener(topics = "${souq.topics.platform.review}")
    @Transactional
    public void onReviewSubmitted(
            @Payload ReviewSubmittedEvent event,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            Acknowledgment ack
    ) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName();

        System.out.println("[PUBLISHER-REVIEW-CONSUMER] Received: " + eventType + " id=" + eventId);

        // 1) Idempotence : Vérifier si déjà traité
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PUBLISHER-REVIEW-CONSUMER] Duplicate ignored: " + eventId);
            ack.acknowledge();
            return;
        }

        // 2) Sauvegarder marqueur de consommation
        consumedEventRepository.save(
                new ConsumedEventEntity(
                        eventId,
                        eventType,
                        event.getOccurredAt(),
                        Instant.now()
                )
        );

        // 3) Traitement métier : Stocker la review reçue
        ReceivedReviewEntity review = new ReceivedReviewEntity(
                event.getReviewId(),
                event.getGameId(),
                event.getUserId(),
                event.getPseudo(),
                event.getNote(),
                event.getDescription(),
                event.getSubmittedAt(),
                Instant.now()
        );

        reviewRepository.save(review);

        System.out.println("[PUBLISHER-REVIEW-CONSUMER] Stored review for game: " + event.getGameId() 
                + " note=" + event.getNote());

        // 4) Acquitter le message
        ack.acknowledge();
    }
}
