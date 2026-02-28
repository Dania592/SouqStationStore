package com.souqstation.publisher.messaging

import com.souqstation.schemas.events.PatchPublishedEvent
import org.springframework.beans.factory.annotation.Value
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Component

@Component
class PublisherPatchEventProducer(
    private val patchTemplate: KafkaTemplate<String, PatchPublishedEvent>,
    @Value("\${souq.kafka.topics.publisher.patch:souq.publisher.patch.events}")
    private val topic: String
) {

    fun publishPatch(key: String, event: PatchPublishedEvent) {
        patchTemplate.send(topic, key, event)
        println("[PRODUCER] PatchPublished published: ${event.patchId}")
    }
}