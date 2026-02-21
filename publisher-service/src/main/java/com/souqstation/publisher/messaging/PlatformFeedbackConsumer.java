package com.souqstation.publisher.messaging;

import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class PlatformFeedbackConsumer {

    @KafkaListener(topics = "${souq.topics.platform}")
    public void onPlatformEvent(ConsumerRecord<String, GenericRecord> record, Acknowledgment ack) {
        GenericRecord payload = record.value();
        if (payload == null) {
            ack.acknowledge();
            return;
        }

        String schemaName = payload.getSchema().getName();
        if (!"ReviewSubmittedEvent".equals(schemaName) && !"IncidentReportedEvent".equals(schemaName)) {
            ack.acknowledge();
            return;
        }

        Object eventId = payload.get("eventId");
        Object gameId = payload.get("gameId");

        System.out.println("[PUBLISHER] feedback consumed"
                + " key=" + record.key()
                + " schema=" + schemaName
                + " eventId=" + eventId
                + " gameId=" + gameId);

        ack.acknowledge();
    }
}
