package com.souqstation.platform.messaging;

import com.souqstation.shared.events.EventEnvelope;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.stereotype.Component;

@Component
public class PublisherEventsConsumer {

    @KafkaListener(topics = "${souq.topics.publisher}")
    public void onEvent(ConsumerRecord<String, EventEnvelope> record, Acknowledgment ack) {
        EventEnvelope event = record.value();
        System.out.println("[PLATFORM] received key=" + record.key()
                + " type=" + event.eventType()
                + " eventId=" + event.eventId()
                + " payload=" + event.payload());

        // V0: on ack direct (plus tard: idempotence + DB)
        ack.acknowledge();
    }
}
