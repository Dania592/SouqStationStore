package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.publisher.persistence.GameEntity;
import com.souqstation.publisher.persistence.GameRepository;
import com.souqstation.publisher.platform.PlatformClient;
import com.souqstation.publisher.service.DLCService;
import com.souqstation.publisher.service.PatchService;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import com.souqstation.schemas.events.DLCPublishedEvent;
import com.souqstation.schemas.events.GamePublished;
import com.souqstation.schemas.events.PatchPublishedEvent;
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
    private final PatchService patchService;
    private final DLCService dlcService;

    public PublisherController(
            PublisherEventProducer producer,
            GameRepository gameRepository,
            PlatformClient platformClient,
            PatchService patchService,
            DLCService dlcService
    ) {
        this.producer = producer;
        this.gameRepository = gameRepository;
        this.platformClient = platformClient;
        this.patchService = patchService;
        this.dlcService = dlcService;
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

    /**
     * Publier un patch pour un jeu
     * POST /publisher/publish-patch?gameId=G1&targetVersion=1.1.0&description=...&modifications=CORRECTION,OPTIMISATION&releasedAt=2026-03-15
     */
    @PostMapping("/publish-patch")
    public ResponseEntity<Map<String, Object>> publishPatch(
            @RequestParam String gameId,
            @RequestParam String targetVersion,
            @RequestParam(required = false) String description,
            @RequestParam List<String> modifications,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date releasedAt
    ) {
        try {
            PatchPublishedEvent event = patchService.publishPatch(
                    gameId,
                    targetVersion,
                    description,
                    modifications,
                    releasedAt.toInstant()
            );

            return ResponseEntity.ok(Map.of(
                    "status", "PATCH_PUBLISHED",
                    "eventId", event.getEventId(),
                    "patchId", event.getPatchId(),
                    "gameId", event.getGameId(),
                    "previousVersion", event.getPreviousVersion(),
                    "targetVersion", event.getTargetVersion(),
                    "modifications", event.getModifications().stream()
                            .map(Enum::name)
                            .toList(),
                    "releasedAt", event.getReleasedAt().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "PATCH_REJECTED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Récupérer l'historique des patches d'un jeu
     * GET /publisher/games/{gameId}/patches
     */
    @GetMapping("/games/{gameId}/patches")
    public ResponseEntity<Map<String, Object>> getPatchesByGame(@PathVariable String gameId) {
        List<Map<String, Object>> patches = patchService.getPatchesByGame(gameId);
        long count = patchService.countPatchesByGame(gameId);

        return ResponseEntity.ok(Map.of(
                "gameId", gameId,
                "patchCount", count,
                "patches", patches
        ));
    }

    /**
     * Publier un DLC
     * POST /publisher/publish-dlc?dlcId=DLC1&gameId=G1&name=DLC Name&publisherId=R1&price=9.99&releaseDate=2026-04-01
     */
    @PostMapping("/publish-dlc")
    public ResponseEntity<Map<String, Object>> publishDLC(
            @RequestParam String dlcId,
            @RequestParam String gameId,
            @RequestParam String name,
            @RequestParam(required = false) String description,
            @RequestParam String publisherId,
            @RequestParam(required = false) Double price,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date releaseDate
    ) {
        try {
            DLCPublishedEvent event = dlcService.publishDLC(
                    dlcId,
                    gameId,
                    name,
                    description,
                    publisherId,
                    price,
                    releaseDate.toInstant()
            );

            return ResponseEntity.ok(Map.of(
                    "status", "DLC_PUBLISHED",
                    "eventId", event.getEventId(),
                    "dlcId", event.getDlcId(),
                    "gameId", event.getGameId(),
                    "name", event.getName(),
                    "publisherId", event.getPublisherId(),
                    "price", event.getPrice() != null ? event.getPrice() : 0.0,
                    "releaseDate", event.getReleaseDate().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "DLC_REJECTED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Récupérer les DLC d'un jeu
     * GET /publisher/games/{gameId}/dlcs
     */
    @GetMapping("/games/{gameId}/dlcs")
    public ResponseEntity<Map<String, Object>> getDLCsByGame(@PathVariable String gameId) {
        List<Map<String, Object>> dlcs = dlcService.getDLCsByGame(gameId);
        long count = dlcService.countDLCsByGame(gameId);

        return ResponseEntity.ok(Map.of(
                "gameId", gameId,
                "dlcCount", count,
                "dlcs", dlcs
        ));
    }
}