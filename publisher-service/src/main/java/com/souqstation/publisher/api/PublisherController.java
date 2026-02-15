package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.schemas.events.GamePublished;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/publisher")
public class PublisherController {

    private final PublisherEventProducer producer;

    public PublisherController(PublisherEventProducer producer) {
        this.producer = producer;
    }

    @RequestMapping(value = "/publish-game", method = {RequestMethod.POST, RequestMethod.GET})
    public GamePublished publishGame(@RequestParam String gameId, @RequestParam String title) {

        GamePublished event = GamePublished.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(Instant.ofEpochSecond(Instant.now().toEpochMilli()))
                .setSchemaVersion(1)
                .setGameId(gameId)
                .setTitle(title)
                .build();

        producer.publish(gameId, event);
        return event;
    }
}