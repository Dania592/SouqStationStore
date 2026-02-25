package com.souqstation.publisher.messaging;

import com.souqstation.publisher.persistence.ConsumedEventEntity;
import com.souqstation.publisher.persistence.ConsumedEventRepository;
import com.souqstation.publisher.persistence.ReceivedIncidentEntity;
import com.souqstation.publisher.persistence.ReceivedIncidentRepository;
import com.souqstation.schemas.events.IncidentReportedEvent;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Component
public class IncidentConsumer {

    private final ReceivedIncidentRepository incidentRepository;
    private final ConsumedEventRepository consumedEventRepository;

    public IncidentConsumer(
            ReceivedIncidentRepository incidentRepository,
            ConsumedEventRepository consumedEventRepository
    ) {
        this.incidentRepository = incidentRepository;
        this.consumedEventRepository = consumedEventRepository;
    }

    @KafkaListener(topics = "${souq.topics.platform.incident}")
    @Transactional
    public void onIncidentReported(
            @Payload IncidentReportedEvent event,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            Acknowledgment ack
    ) {
        String eventId = event.getEventId();
        String eventType = event.getSchema().getName();

        System.out.println("[PUBLISHER-INCIDENT-CONSUMER] Received: " + eventType + " id=" + eventId);

        // 1) Idempotence : Vérifier si déjà traité
        if (consumedEventRepository.existsById(eventId)) {
            System.out.println("[PUBLISHER-INCIDENT-CONSUMER] Duplicate ignored: " + eventId);
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

        // 3) Traitement métier : Stocker l'incident reçu
        ReceivedIncidentEntity.IncidentSeverity severity = ReceivedIncidentEntity.IncidentSeverity
                .valueOf(event.getSeverity().name());

        ReceivedIncidentEntity incident = new ReceivedIncidentEntity(
                event.getIncidentId(),
                event.getGameId(),
                event.getUserId(),
                event.getPseudo(),
                severity,
                event.getDescription(),
                event.getEnvironment(),
                event.getReportedAt(),
                Instant.now()
        );

        incidentRepository.save(incident);

        System.out.println("[PUBLISHER-INCIDENT-CONSUMER] Stored incident for game: " + event.getGameId() 
                + " severity=" + event.getSeverity());

        // 4) Acquitter le message
        ack.acknowledge();
    }
}
