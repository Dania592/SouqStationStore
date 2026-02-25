package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.IncidentReportedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformIncidentEventProducer {

    private final KafkaTemplate<String, IncidentReportedEvent> incidentTemplate;

    private final String incidentTopic;

    public PlatformIncidentEventProducer(
            KafkaTemplate<String, IncidentReportedEvent> incidentTemplate,
            @Value("${souq.kafka.topics.platform.incident}") String incidentTopic
    ) {
        this.incidentTemplate = incidentTemplate;
        this.incidentTopic = incidentTopic;
    }

    public void publishIncident(String key, IncidentReportedEvent event) {
        incidentTemplate.send(incidentTopic, key, event);
        System.out.println("[PRODUCER] IncidentReported published: " + event.getIncidentId());
    }
}
