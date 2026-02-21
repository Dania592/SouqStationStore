package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import com.souqstation.schemas.events.GamePublished;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/publisher")
public class PublisherController {

    private static final Schema PATCH_PUBLISHED_SCHEMA = loadSchema("schemas/events/patch-published.avsc");
    private static final Schema DLC_PUBLISHED_SCHEMA = loadSchema("schemas/events/dlc-published.avsc");

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
            @RequestParam String idEditeur,
            @RequestParam(defaultValue = "1") String version,
            @RequestParam(defaultValue = "0.0") float prixInit
    ) {
        String eventId = UUID.randomUUID().toString();
        Instant now = Instant.now();

        GamePublished event = GamePublished.newBuilder()
                .setEventId(eventId)
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setGameId(gameId)
                .setTitle(title)
                .setDescription(description)
                .setPlatformExc(platform)
                .setGenres(genre)
                .setIdEditeur(idEditeur)
                .setVersion(version)
                .setPrixInit(prixInit)
                .build();

        producer.publishGame(gameId, event);

        return ResponseEntity.ok(Map.ofEntries(
                Map.entry("status", "PUBLISHED_TO_KAFKA"),
                Map.entry("eventId", eventId),
                Map.entry("gameId", gameId),
                Map.entry("title", title),
                Map.entry("description", description),
                Map.entry("platform", platform.name()),
                Map.entry("genre", genre.name()),
                Map.entry("idEditeur", idEditeur),
                Map.entry("version", version),
                Map.entry("prixInit", prixInit),
                Map.entry("occurredAt", now.toString())
        ));
    }

    @RequestMapping(value = "/publish-patch", method = {RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Map<String, Object>> publishPatch(
            @RequestParam String patchId,
            @RequestParam String gameId,
            @RequestParam String previousVersion,
            @RequestParam String targetVersion,
            @RequestParam(required = false) String description,
            @RequestParam(defaultValue = "CORRECTION") String modifications
    ) {
        String eventId = UUID.randomUUID().toString();
        long nowMillis = Instant.now().toEpochMilli();

        GenericRecord event = new GenericData.Record(PATCH_PUBLISHED_SCHEMA);
        event.put("eventId", eventId);
        event.put("eventType", "patch.published");
        event.put("occurredAt", nowMillis);
        event.put("schemaVersion", 1);
        event.put("patchId", patchId);
        event.put("gameId", gameId);
        event.put("previousVersion", previousVersion);
        event.put("targetVersion", targetVersion);
        event.put("description", description);
        event.put("modifications", parseModificationTypes(modifications));
        event.put("releasedAt", nowMillis);

        producer.publishPatch(gameId, event);

        return ResponseEntity.ok(Map.ofEntries(
                Map.entry("status", "PUBLISHED_TO_KAFKA"),
                Map.entry("eventType", "PatchPublishedEvent"),
                Map.entry("eventId", eventId),
                Map.entry("patchId", patchId),
                Map.entry("gameId", gameId),
                Map.entry("targetVersion", targetVersion)
        ));
    }

    @RequestMapping(value = "/publish-dlc", method = {RequestMethod.POST, RequestMethod.GET})
    public ResponseEntity<Map<String, Object>> publishDlc(
            @RequestParam String dlcId,
            @RequestParam String gameId,
            @RequestParam String name,
            @RequestParam(required = false) String description,
            @RequestParam String publisherId,
            @RequestParam(defaultValue = "0.0") double price
    ) {
        String eventId = UUID.randomUUID().toString();
        long nowMillis = Instant.now().toEpochMilli();

        GenericRecord event = new GenericData.Record(DLC_PUBLISHED_SCHEMA);
        event.put("eventId", eventId);
        event.put("eventType", "dlc.published");
        event.put("occurredAt", nowMillis);
        event.put("schemaVersion", 1);
        event.put("dlcId", dlcId);
        event.put("gameId", gameId);
        event.put("name", name);
        event.put("description", description);
        event.put("publisherId", publisherId);
        event.put("price", price);
        event.put("releaseDate", nowMillis);

        producer.publishDlc(gameId, event);

        return ResponseEntity.ok(Map.ofEntries(
                Map.entry("status", "PUBLISHED_TO_KAFKA"),
                Map.entry("eventType", "DLCPublishedEvent"),
                Map.entry("eventId", eventId),
                Map.entry("dlcId", dlcId),
                Map.entry("gameId", gameId),
                Map.entry("name", name)
        ));
    }

    private static List<GenericData.EnumSymbol> parseModificationTypes(String modificationsParam) {
        Schema enumSchema = PATCH_PUBLISHED_SCHEMA
                .getField("modifications")
                .schema()
                .getElementType();

        List<GenericData.EnumSymbol> values = new ArrayList<>();
        Arrays.stream(modificationsParam.split(","))
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .forEach(rawValue -> values.add(new GenericData.EnumSymbol(enumSchema, rawValue)));
        return values;
    }

    private static Schema loadSchema(String schemaPath) {
        try {
            String rawSchema = Files.readString(Path.of(schemaPath));
            return new Schema.Parser().parse(rawSchema);
        } catch (IOException e) {
            throw new IllegalStateException("Unable to load schema: " + schemaPath, e);
        }
    }
}