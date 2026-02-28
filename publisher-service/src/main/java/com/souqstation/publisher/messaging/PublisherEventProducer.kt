package com.souqstation.publisher.messaging

import com.souqstation.schemas.events.GamePublished
import com.souqstation.schemas.events.DLCPublishedEvent
import org.apache.avro.generic.GenericRecord
import org.springframework.beans.factory.annotation.Value
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Component

@Component
class PublisherEventProducer(
    private val kafkaTemplate: KafkaTemplate<String, Any>,
    @Value("\${souq.topics.publisher}")
    private val topic: String
) {

    fun publishGame(key: String, event: GamePublished) {
        kafkaTemplate.send(topic, key, event)
    }

    fun publishPatch(key: String, event: GenericRecord) {
        kafkaTemplate.send(topic, key, event)
    }

    fun publishDlc(key: String, event: DLCPublishedEvent) {
        kafkaTemplate.send(topic, key, event)
    }
}