package com.souqstation.publisher.messaging

import org.apache.avro.generic.GenericRecord
import org.apache.kafka.clients.consumer.ConsumerRecord
import org.springframework.kafka.annotation.KafkaListener
import org.springframework.kafka.support.Acknowledgment
import org.springframework.stereotype.Component

@Component
class PlatformFeedbackConsumer {

    @KafkaListener(topics = ["\${souq.topics.platform}"])
    fun onPlatformEvent(
        record: ConsumerRecord<String, GenericRecord>,
        ack: Acknowledgment
    ) {
        val payload = record.value()
        if (payload == null) {
            ack.acknowledge()
            return
        }

        val schemaName = payload.schema.name
        if (schemaName != "ReviewSubmittedEvent" &&
            schemaName != "IncidentReportedEvent"
        ) {
            ack.acknowledge()
            return
        }

        val eventId = payload["eventId"]
        val gameId = payload["gameId"]

        println(
            "[PUBLISHER] feedback consumed" +
                    " key=${record.key()}" +
                    " schema=$schemaName" +
                    " eventId=$eventId" +
                    " gameId=$gameId"
        )

        ack.acknowledge()
    }
}