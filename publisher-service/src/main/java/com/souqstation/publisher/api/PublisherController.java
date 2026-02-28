package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.publisher.persistence.DlcEntity;
import com.souqstation.publisher.persistence.DlcRepository;
import com.souqstation.publisher.persistence.GameEntity;
import com.souqstation.publisher.persistence.GameRepository;
import com.souqstation.publisher.platform.PlatformClient;
import com.souqstation.publisher.service.PatchService;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import com.souqstation.schemas.events.GamePublished;
import com.souqstation.schemas.events.PatchPublishedEvent;
import com.souqstation.schemas.events.DLCPublishedEvent;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/publisher")
public class PublisherController {

        private final PublisherEventProducer producer;
        private final GameRepository gameRepository;
        private final PlatformClient platformClient;
        private final PatchService patchService;
        private final DlcRepository dlcRepository;

        public PublisherController(
                PublisherEventProducer producer,
                GameRepository gameRepository,
                PlatformClient platformClient,
                PatchService patchService, DlcRepository dlcRepository) {
                this.producer = producer;
                this.gameRepository = gameRepository;
                this.platformClient = platformClient;
                this.patchService = patchService;
            this.dlcRepository = dlcRepository;
        }

        @RequestMapping(value = "/publish-game", method = { RequestMethod.POST, RequestMethod.GET })
        public ResponseEntity<Map<String, Object>> publishGame(
                        @RequestParam String gameId,
                        @RequestParam String title,
                        @RequestParam(required = false) String description,
                        @RequestParam ExecPlatform platform,
                        @RequestParam GameGenre genre,
                        @RequestParam(name = "idEditeur") String publisherId,
                        @RequestParam(defaultValue = "1") String version,
                        @RequestParam(defaultValue = "0.0") float prixInit,
                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date releaseDate) {
                // 1) Vérifier que le rédacteur/publisher existe
                if (!platformClient.redactorExists(publisherId)) {
                        return ResponseEntity.badRequest().body(Map.of(
                                        "status", "REJECTED",
                                        "reason", "REDACTOR_NOT_FOUND",
                                        "publisherId", publisherId));
                }

                // 2) Vérifier que le gameId n'existe pas déjà (évite doublons)
                if (gameRepository.existsByGameId(gameId)) {
                        return ResponseEntity.badRequest().body(Map.of(
                                        "status", "REJECTED",
                                        "reason", "GAME_ID_ALREADY_EXISTS",
                                        "gameId", gameId));
                }

                Instant now = Instant.now();

                // 3) Sauvegarder en base
                Double price = (double) prixInit;
                Instant releaseDateInstant = (releaseDate != null) ? releaseDate.toInstant() : now;

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
                                                releaseDateInstant,
                                                now));

                // 4) Publier l'event Kafka (schéma Avro)
                String eventId = UUID.randomUUID().toString();

                GamePublished event = GamePublished.newBuilder()
                                .setEventId(eventId)
                                .setOccurredAt(now)
                                .setSchemaVersion(1)
                                .setGameId(saved.getGameId())
                                .setName(saved.getName())
                                .setDescription(saved.getDescription())
                                .setPlatformExc(saved.getPlatformExc())
                                .setGenres(saved.getGenre())
                                .setPublisherId(saved.getPublisherId())
                                .setVersion(saved.getVersion())
                                .setPrice(saved.getPrice())
                                .setReleaseDate(releaseDateInstant)
                                .build();

                producer.publishGame(gameId, event);

                return ResponseEntity.ok(Map.ofEntries(
                                Map.entry("status", "PUBLISHED_TO_KAFKA"),
                                Map.entry("eventId", eventId),
                                Map.entry("gameId", gameId),
                                Map.entry("title", title),
                                Map.entry("description", description != null ? description : ""),
                                Map.entry("platform", platform.name()),
                                Map.entry("genre", genre.name()),
                                Map.entry("idEditeur", publisherId),
                                Map.entry("version", version),
                                Map.entry("prixInit", prixInit),
                                Map.entry("occurredAt", now.toString())));
        }

        @RequestMapping(value = "/publish-dlc", method = { RequestMethod.POST, RequestMethod.GET })
        public ResponseEntity<Map<String, Object>> publishDlc(
                @RequestParam String dlcId,
                @RequestParam String gameId,
                @RequestParam String name,
                @RequestParam(required = false) String description,
                @RequestParam String publisherId,
                @RequestParam(defaultValue = "0.0") double price) {

                // vérifier que le publisher existe
                if (!platformClient.redactorExists(publisherId)) {
                        return ResponseEntity.badRequest().body(Map.of(
                                "status", "REJECTED",
                                "reason", "REDACTOR_NOT_FOUND",
                                "publisherId", publisherId));
                }

                // vérifier que le jeu existe dans le publisher-service
                if (!gameRepository.existsByGameId(gameId)) {
                        return ResponseEntity.badRequest().body(Map.of(
                                "status", "REJECTED",
                                "reason", "GAME_NOT_FOUND",
                                "gameId", gameId));
                }

                // éviter doublons
                if (dlcRepository.existsById(dlcId)) {
                        return ResponseEntity.badRequest().body(Map.of(
                                "status", "REJECTED",
                                "reason", "DLC_ID_ALREADY_EXISTS",
                                "dlcId", dlcId));
                }

                Instant now = Instant.now();
                String eventId = UUID.randomUUID().toString();

                // 1) Sauver en base (publisher)
                dlcRepository.save(new DlcEntity(
                        dlcId,
                        gameId,
                        name,
                        description,
                        publisherId,
                        price,
                        now,
                        now
                ));

                // 2) Publier l'event Kafka (Avro)
                DLCPublishedEvent event = DLCPublishedEvent.newBuilder()
                        .setEventId(eventId)
                        .setEventType("dlc.published")
                        .setOccurredAt(now)
                        .setSchemaVersion(1)
                        .setDlcId(dlcId)
                        .setGameId(gameId)
                        .setName(name)
                        .setDescription(description)
                        .setPublisherId(publisherId)
                        .setPrice(price)
                        .setReleaseDate(now)
                        .build();

                producer.publishDlc(gameId, event);

                return ResponseEntity.ok(Map.ofEntries(
                        Map.entry("status", "PUBLISHED_TO_KAFKA"),
                        Map.entry("eventType", "DLCPublishedEvent"),
                        Map.entry("eventId", eventId),
                        Map.entry("dlcId", dlcId),
                        Map.entry("gameId", gameId),
                        Map.entry("name", name),
                        Map.entry("publisherId", publisherId),
                        Map.entry("price", price),
                        Map.entry("occurredAt", now.toString())
                ));
        }

        @GetMapping("/games/by-publisher")
        public ResponseEntity<?> getGamesByPublisher(
                        @RequestParam(name = "idEditeur") String publisherId) {
                if (!platformClient.redactorExists(publisherId)) {
                        return ResponseEntity.badRequest().body(Map.of(
                                        "status", "REJECTED",
                                        "reason", "REDACTOR_NOT_FOUND",
                                        "publisherId", publisherId));
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
                                        m.put("price", g.getPrice());
                                        m.put("releaseDate", g.getReleaseDate());
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
         * POST
         * /publisher/publish-patch?gameId=G1&targetVersion=1.1.0&description=...&modifications=CORRECTION,OPTIMISATION&releasedAt=2026-03-15
         */
        @PostMapping("/publish-patch")
        public ResponseEntity<Map<String, Object>> publishPatch(
                        @RequestParam String gameId,
                        @RequestParam String targetVersion,
                        @RequestParam(required = false) String description,
                        @RequestParam List<String> modifications,
                        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date releasedAt) {
                try {
                        PatchPublishedEvent event = patchService.publishPatch(
                                        gameId,
                                        targetVersion,
                                        description,
                                        modifications,
                                        releasedAt.toInstant());

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
                                        "releasedAt", event.getReleasedAt().toString()));
                } catch (IllegalArgumentException e) {
                        return ResponseEntity.badRequest().body(Map.of(
                                        "status", "PATCH_REJECTED",
                                        "reason", e.getMessage()));
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
                                "patches", patches));
        }

        @GetMapping("/games/{gameId}/dlcs")
        public ResponseEntity<Map<String, Object>> getDlcsByGame(@PathVariable String gameId) {

                List<DlcEntity> dlcs = dlcRepository.findByGameId(gameId);

                List<Map<String, Object>> result = dlcs.stream()
                        .map(d -> {
                                Map<String, Object> m = new LinkedHashMap<>();
                                m.put("dlcId", d.getDlcId());
                                m.put("gameId", d.getGameId());
                                m.put("name", d.getName());
                                m.put("description", d.getDescription());
                                m.put("publisherId", d.getPublisherId());
                                m.put("price", d.getPrice());
                                m.put("releaseDate", d.getReleaseDate());
                                return m;
                        })
                        .toList();

                return ResponseEntity.ok(Map.of(
                        "gameId", gameId,
                        "dlcCount", result.size(),
                        "dlcs", result
                ));
        }
}