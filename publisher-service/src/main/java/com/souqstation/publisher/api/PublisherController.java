package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import com.souqstation.schemas.events.GamePublished;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/publisher")
public class PublisherController {

    private final PublisherEventProducer producer;

    public PublisherController(PublisherEventProducer producer) {
        this.producer = producer;
    }

    @RequestMapping(value = "/publish-game", method = {RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Map<String, Object>> publishGame(
            @RequestParam String gameId,
            @RequestParam String title,
            @RequestParam String description,
            @RequestParam ExecPlatform platform,
            @RequestParam GameGenre genre,
            @RequestParam String idEditeur
    ) {
        String eventId = UUID.randomUUID().toString();
        Instant now = Instant.now();

        GamePublished event = GamePublished.newBuilder()
                .setEventId(eventId)
                .setOccurredAt(Instant.ofEpochSecond(now.toEpochMilli()))
                .setSchemaVersion(1)
                .setGameId(gameId)
                .setTitle(title)
                .setDescription(description)
                .setPlatformExc(platform)
                .setGenres(genre)
                .setIdEditeur(idEditeur)
                .build();

        producer.publish(gameId, event);

        return ResponseEntity.ok(Map.of(
                "status", "PUBLISHED_TO_KAFKA",
                "eventId", eventId,
                "gameId", gameId,
                "title", title,
                "description", description,
                "platform", platform.name(),
                "genre", genre.name(),
                "idEditeur", idEditeur,
                "occurredAt", now.toString()
        ));
    }
}