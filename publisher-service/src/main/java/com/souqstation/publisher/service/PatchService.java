package com.souqstation.publisher.service;

import com.souqstation.publisher.messaging.PublisherPatchEventProducer;
import com.souqstation.publisher.persistence.*;
import com.souqstation.schemas.events.PatchPublishedEvent;
import com.souqstation.schemas.events.enums.ModificationType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class PatchService {

    private final PatchRepository patchRepository;
    private final GameRepository gameRepository;
    private final PublisherPatchEventProducer producer;
    private final DlcRepository dlcRepository;

    public PatchService(
            PatchRepository patchRepository,
            GameRepository gameRepository,
            PublisherPatchEventProducer producer, DlcRepository dlcRepository
    ) {
        this.patchRepository = patchRepository;
        this.gameRepository = gameRepository;
        this.producer = producer;
        this.dlcRepository = dlcRepository;
    }

    @Transactional
    public PatchPublishedEvent publishPatch(
            String gameId,
            String targetVersion,
            String description,
            List<String> modificationsList,
            Instant releasedAt
    ) {
        Instant now = Instant.now();

        // 1) Vérifier que le jeu existe
        GameEntity game = gameRepository.findById(gameId)
                .orElseThrow(() -> new IllegalArgumentException("Game not found: " + gameId));

        // 2) Récupérer la version actuelle du jeu
        String previousVersion = game.getVersion();

        // 3) Vérifier que la nouvelle version est différente
        if (previousVersion.equals(targetVersion)) {
            throw new IllegalArgumentException("Target version must be different from current version: " + previousVersion);
        }

        // 4) Vérifier que cette version n'existe pas déjà
        if (patchRepository.existsByGameIdAndTargetVersion(gameId, targetVersion)) {
            throw new IllegalArgumentException("A patch with this target version already exists: " + targetVersion);
        }

        // 5) Parser les types de modifications
        List<PatchEntity.ModificationType> jpaModifications = modificationsList.stream()
                .map(m -> PatchEntity.ModificationType.valueOf(m.toUpperCase()))
                .collect(Collectors.toList());

        List<ModificationType> avroModifications = modificationsList.stream()
                .map(m -> ModificationType.valueOf(m.toUpperCase()))
                .collect(Collectors.toList());

        // 6) Créer le patch
        String patchId = UUID.randomUUID().toString();
        PatchEntity patch = new PatchEntity(
                patchId,
                gameId,
                previousVersion,
                targetVersion,
                description,
                jpaModifications,
                releasedAt,
                now
        );

        patchRepository.save(patch);

        // 7) Mettre à jour la version du jeu
        game.setVersion(targetVersion);
        gameRepository.save(game);

        // 8) Créer l'événement Avro
        PatchPublishedEvent event = PatchPublishedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setPatchId(patchId)
                .setGameId(gameId)
                .setPreviousVersion(previousVersion)
                .setTargetVersion(targetVersion)
                .setDescription(description)
                .setModifications(avroModifications)
                .setReleasedAt(releasedAt)
                .build();

        // 9) Publier vers Kafka
        producer.publishPatch(gameId, event);

        return event;
    }

    public List<Map<String, Object>> getPatchesByGame(String gameId) {
        List<PatchEntity> patches = patchRepository.findByGameIdOrderByReleasedAtDesc(gameId);
        return convertToMapList(patches);
    }

    public long countPatchesByGame(String gameId) {
        return patchRepository.countByGameId(gameId);
    }

    // Méthodes utilitaires
    private List<Map<String, Object>> convertToMapList(List<PatchEntity> patches) {
        return patches.stream()
                .map(this::convertToMap)
                .collect(Collectors.toList());
    }

    private Map<String, Object> convertToMap(PatchEntity patch) {
        return Map.of(
                "patchId", patch.getPatchId(),
                "gameId", patch.getGameId(),
                "previousVersion", patch.getPreviousVersion(),
                "targetVersion", patch.getTargetVersion(),
                "description", patch.getDescription() != null ? patch.getDescription() : "",
                "modifications", patch.getModifications().stream()
                        .map(Enum::name)
                        .collect(Collectors.toList()),
                "releasedAt", patch.getReleasedAt().toString(),
                "createdAt", patch.getCreatedAt().toString()
        );
    }

    public List<Map<String, Object>> getDlcsByGame(String gameId) {
        return dlcRepository.findByGameId(gameId)
                .stream()
                .map(d -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("dlcId", d.getDlcId());
                    m.put("name", d.getName());
                    m.put("description", d.getDescription());
                    m.put("price", d.getPrice());
                    m.put("releaseDate", d.getReleaseDate());
                    return m;
                })
                .toList();
    }
}
