package com.souqstation.publisher.service;

import com.souqstation.publisher.messaging.PublisherDLCEventProducer;
import com.souqstation.publisher.persistence.DLCEntity;
import com.souqstation.publisher.persistence.DLCRepository;
import com.souqstation.publisher.persistence.GameEntity;
import com.souqstation.publisher.persistence.GameRepository;
import com.souqstation.schemas.events.DLCPublishedEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class DLCService {

    private final DLCRepository dlcRepository;
    private final GameRepository gameRepository;
    private final PublisherDLCEventProducer producer;

    public DLCService(
            DLCRepository dlcRepository,
            GameRepository gameRepository,
            PublisherDLCEventProducer producer
    ) {
        this.dlcRepository = dlcRepository;
        this.gameRepository = gameRepository;
        this.producer = producer;
    }

    @Transactional
    public DLCPublishedEvent publishDLC(
            String dlcId,
            String gameId,
            String name,
            String description,
            String publisherId,
            Double price,
            Instant releaseDate
    ) {
        Instant now = Instant.now();

        // 1) Vérifier que le jeu parent existe
        GameEntity game = gameRepository.findById(gameId)
                .orElseThrow(() -> new IllegalArgumentException("Parent game not found: " + gameId));

        // 2) Vérifier que l'éditeur correspond
        if (!game.getPublisherId().equals(publisherId)) {
            throw new IllegalArgumentException("Publisher mismatch. Game publisher: " + game.getPublisherId());
        }

        // 3) Vérifier que le DLC n'existe pas déjà
        if (dlcRepository.existsById(dlcId)) {
            throw new IllegalArgumentException("DLC already exists: " + dlcId);
        }

        // 4) Créer le DLC
        DLCEntity dlc = new DLCEntity(
                dlcId,
                gameId,
                name,
                description,
                publisherId,
                price,
                releaseDate,
                now
        );

        dlcRepository.save(dlc);

        // 5) Créer l'événement Avro
        DLCPublishedEvent event = DLCPublishedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setDlcId(dlcId)
                .setGameId(gameId)
                .setName(name)
                .setDescription(description)
                .setPublisherId(publisherId)
                .setPrice(price)
                .setReleaseDate(releaseDate)
                .build();

        // 6) Publier vers Kafka
        producer.publishDLC(gameId, event);

        return event;
    }

    public List<Map<String, Object>> getDLCsByGame(String gameId) {
        List<DLCEntity> dlcs = dlcRepository.findByGameId(gameId);
        return convertToMapList(dlcs);
    }

    public long countDLCsByGame(String gameId) {
        return dlcRepository.countByGameId(gameId);
    }

    // Méthodes utilitaires
    private List<Map<String, Object>> convertToMapList(List<DLCEntity> dlcs) {
        return dlcs.stream()
                .map(this::convertToMap)
                .collect(Collectors.toList());
    }

    private Map<String, Object> convertToMap(DLCEntity dlc) {
        return Map.of(
                "dlcId", dlc.getDlcId(),
                "gameId", dlc.getGameId(),
                "name", dlc.getName(),
                "description", dlc.getDescription() != null ? dlc.getDescription() : "",
                "publisherId", dlc.getPublisherId(),
                "price", dlc.getPrice() != null ? dlc.getPrice() : 0.0,
                "releaseDate", dlc.getReleaseDate().toString(),
                "createdAt", dlc.getCreatedAt().toString()
        );
    }
}
