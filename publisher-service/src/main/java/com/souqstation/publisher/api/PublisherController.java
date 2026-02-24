package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.publisher.persistence.GameEntity;
import com.souqstation.publisher.persistence.GameRepository;
import com.souqstation.publisher.platform.PlatformClient;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import com.souqstation.schemas.events.GamePublished;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.Serializable;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/publisher")
public class PublisherController {

    private final PublisherEventProducer producer;
    private final GameRepository gameRepository;
    private final PlatformClient platformClient;

    public PublisherController(PublisherEventProducer producer,
                               GameRepository gameRepository,
                               PlatformClient platformClient) {
        this.producer = producer;
        this.gameRepository = gameRepository;
        this.platformClient = platformClient;
    }

    @RequestMapping(value = "/publish-game", method = {RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Map<String, Object>> publishGame(
            @RequestParam String gameId,
            @RequestParam String title,
            @RequestParam(required = false) String description,
            @RequestParam ExecPlatform platform,
            @RequestParam GameGenre genre,
            @RequestParam(name = "idEditeur") String publisherId,
            @RequestParam String version,
            @RequestParam(required = false) Double price,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date releaseDate
    ) {
        // 1) Vérifier que le rédacteur/publisher existe
        if (!platformClient.redactorExists(publisherId)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "REJECTED",
                    "reason", "REDACTOR_NOT_FOUND",
                    "publisherId", publisherId
            ));
        }

        // 2) Vérifier que le gameId n'existe pas déjà (évite doublons)
        if (gameRepository.existsById(gameId)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "REJECTED",
                    "reason", "GAME_ID_ALREADY_EXISTS",
                    "gameId", gameId
            ));
        }

        Instant now = Instant.now();

        // 3) Sauvegarder en base
        GameEntity saved = gameRepository.save(
                new GameEntity(
                        gameId,
                        title,
                        description,
                        publisherId,
                        platform,
                        genre,
                        version,
                        price,
                        releaseDate.toInstant(),
                        now
                )
        );

        // 4) Publier l'event Kafka (schéma Avro)
        String eventId = UUID.randomUUID().toString();

        GamePublished event = GamePublished.newBuilder()
                .setEventId(eventId)
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setGameId(saved.getGameId())
                .setName(saved.getName())
                .setDescription(saved.getDescription()) // null ok
                .setPublisherId(saved.getPublisherId())
                .setPlatformExc(saved.getPlatformExc())
                .setGenres(saved.getGenre())
                .setVersion(saved.getVersion())
                .setPrice(saved.getPrice()) // null ok
                .setReleaseDate(saved.getReleaseDate())
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
                "idEditeur", publisherId,
                "occurredAt", now.toString()
        ));
    }

    @GetMapping("/games/by-publisher")
    public ResponseEntity<?> getGamesByPublisher(
            @RequestParam(name = "idEditeur") String publisherId
    ) {
        // sécurité métier
        if (!platformClient.redactorExists(publisherId)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "REJECTED",
                    "reason", "REDACTOR_NOT_FOUND",
                    "publisherId", publisherId
            ));
        }

        List<GameEntity> games = gameRepository.findByPublisherId(publisherId);

        List<Map<String, Object>> result = games.stream()
                .map(g -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("gameId", g.getGameId());
                    m.put("title", g.getName());
                    m.put("platform", g.getPlatformExc().name());
                    m.put("genre", g.getGenre().name());
                    m.put("version", g.getVersion());
                    m.put("price", g.getPrice()); // Double (nullable) OK
                    m.put("releaseDate", g.getReleaseDate()); // Instant OK (Jackson)
                    return m;
                })
                .toList();

        return ResponseEntity.ok(result);
    }

    @GetMapping("/games/count")
    public long countGames(@RequestParam(name = "idEditeur") String publisherId) {
        return gameRepository.countByPublisherId(publisherId);
    }
}