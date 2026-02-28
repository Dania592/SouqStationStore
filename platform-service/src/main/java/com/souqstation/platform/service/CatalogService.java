package com.souqstation.platform.service;

import com.souqstation.platform.persistence.GameCatalogEntity;
import com.souqstation.platform.persistence.GameCatalogRepository;
import com.souqstation.platform.persistence.DlcEntity;
import com.souqstation.platform.persistence.DlcRepository;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import com.souqstation.schemas.events.GamePublished;
import com.souqstation.schemas.events.DLCPublishedEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
public class CatalogService {

    private final GameCatalogRepository gameCatalogRepository;
    private final DlcRepository dlcRepository;

    public CatalogService(GameCatalogRepository gameCatalogRepository, DlcRepository dlcRepository) {
        this.gameCatalogRepository = gameCatalogRepository;
        this.dlcRepository = dlcRepository;
    }

    @Transactional
    public void addGameToCatalog(GamePublished event) {
        String gameId = event.getGameId();

        // Vérifier si le jeu est déjà dans le catalogue
        if (gameCatalogRepository.existsById(gameId)) {
            System.out.println("[CATALOG] Game already in catalog: " + gameId);
            return;
        }

        // Créer l'entrée dans le catalogue
        GameCatalogEntity catalogEntry = new GameCatalogEntity(
                gameId,
                event.getName(),
                event.getDescription(),
                event.getPublisherId(),
                event.getPlatformExc(),
                event.getGenres(),
                event.getVersion(),
                event.getPrice(),
                event.getReleaseDate(),
                Instant.now());

        gameCatalogRepository.save(catalogEntry);

        System.out.println("[CATALOG] Game added to catalog: " + gameId + " - " + event.getName());
    }

    @Transactional
    public void addDlcToCatalog(DLCPublishedEvent event) {
        String dlcId = event.getDlcId();

        if (dlcRepository.existsById(dlcId)) {
            System.out.println("[CATALOG] DLC already in catalog: " + dlcId);
            return;
        }

        DlcEntity dlcEntry = new DlcEntity(
                dlcId,
                event.getGameId(),
                event.getName(),
                event.getDescription(),
                event.getPublisherId(),
                event.getPrice(),
                event.getReleaseDate());

        dlcRepository.save(dlcEntry);

        System.out.println("[CATALOG] DLC added to catalog: " + dlcId + " - " + event.getName());
    }

    @Transactional
    public void updateGameVersion(String gameId, String newVersion) {
        GameCatalogEntity game = gameCatalogRepository.findById(gameId)
                .orElseThrow(() -> new IllegalArgumentException("Game not found in catalog: " + gameId));

        game.updateVersion(newVersion);
        gameCatalogRepository.save(game);

        System.out.println("[CATALOG] Game version updated: " + gameId + " -> " + newVersion);
    }

    public List<Map<String, Object>> getAllGames() {
        List<GameCatalogEntity> games = gameCatalogRepository.findAll();
        return convertToMapList(games);
    }

    public Optional<Map<String, Object>> getGameById(String gameId) {
        return gameCatalogRepository.findById(gameId)
                .map(this::convertToMap);
    }

    public List<Map<String, Object>> getGamesByGenre(GameGenre genre) {
        List<GameCatalogEntity> games = gameCatalogRepository.findByGenre(genre);
        return convertToMapList(games);
    }

    public List<Map<String, Object>> getGamesByPlatform(ExecPlatform platform) {
        List<GameCatalogEntity> games = gameCatalogRepository.findByPlatformExc(platform);
        return convertToMapList(games);
    }

    public List<Map<String, Object>> getGamesByGenreAndPlatform(GameGenre genre, ExecPlatform platform) {
        List<GameCatalogEntity> games = gameCatalogRepository.findByGenreAndPlatformExc(genre, platform);
        return convertToMapList(games);
    }

    public List<Map<String, Object>> getGamesByMaxPrice(Double maxPrice) {
        List<GameCatalogEntity> games = gameCatalogRepository.findByPriceLessThanEqual(maxPrice);
        return convertToMapList(games);
    }

    public List<Map<String, Object>> getGamesByPublisher(String publisherId) {
        List<GameCatalogEntity> games = gameCatalogRepository.findByPublisherId(publisherId);
        return convertToMapList(games);
    }

    public long countGamesByPublisher(String publisherId) {
        return gameCatalogRepository.countByPublisherId(publisherId);
    }

    public List<Map<String, Object>> getDlcsByGame(String gameId) {
        List<DlcEntity> dlcs = dlcRepository.findByGameId(gameId);
        return dlcs.stream().map(d -> Map.<String, Object>of(
                "dlcId", d.getDlcId(),
                "gameId", d.getGameId(),
                "name", d.getName(),
                "description", d.getDescription() != null ? d.getDescription() : "",
                "publisherId", d.getPublisherId(),
                "price", d.getPrice() != null ? d.getPrice() : 0.0,
                "releaseDate", d.getReleaseDate().toString())).collect(Collectors.toList());
    }

    // Méthodes utilitaires de conversion
    private List<Map<String, Object>> convertToMapList(List<GameCatalogEntity> games) {
        return games.stream()
                .map(this::convertToMap)
                .collect(Collectors.toList());
    }

    private Map<String, Object> convertToMap(GameCatalogEntity game) {
        return Map.ofEntries(
                Map.entry("gameId", game.getGameId()),
                Map.entry("name", game.getName()),
                Map.entry("description", game.getDescription() != null ? game.getDescription() : ""),
                Map.entry("publisherId", game.getPublisherId()),
                Map.entry("platform", game.getPlatformExc().name()),
                Map.entry("genre", game.getGenre().name()),
                Map.entry("version", game.getVersion()),
                Map.entry("price", game.getPrice() != null ? game.getPrice() : 0.0),
                Map.entry("releaseDate", game.getReleaseDate().toString()),
                Map.entry("addedAt", game.getAddedAt().toString()),
                Map.entry("updatedAt", game.getUpdatedAt().toString()));
    }

}
