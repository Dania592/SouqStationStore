package com.souqstation.platform.api;

import com.souqstation.platform.service.CatalogService;
import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/platform/catalog")
public class CatalogController {

    private final CatalogService catalogService;

    public CatalogController(CatalogService catalogService) {
        this.catalogService = catalogService;
    }

    /**
     * Récupérer tous les jeux du catalogue
     * GET /platform/catalog/games
     */
    @GetMapping("/games")
    public ResponseEntity<Map<String, Object>> getAllGames(
            @RequestParam(required = false) GameGenre genre,
            @RequestParam(required = false) ExecPlatform platform,
            @RequestParam(required = false) Double maxPrice
    ) {
        List<Map<String, Object>> games;

        // Filtrer selon les paramètres
        if (genre != null && platform != null) {
            games = catalogService.getGamesByGenreAndPlatform(genre, platform);
        } else if (genre != null) {
            games = catalogService.getGamesByGenre(genre);
        } else if (platform != null) {
            games = catalogService.getGamesByPlatform(platform);
        } else if (maxPrice != null) {
            games = catalogService.getGamesByMaxPrice(maxPrice);
        } else {
            games = catalogService.getAllGames();
        }

        return ResponseEntity.ok(Map.of(
                "totalGames", games.size(),
                "games", games
        ));
    }

    /**
     * Détails d'un jeu spécifique
     * GET /platform/catalog/games/{gameId}
     */
    @GetMapping("/games/{gameId}")
    public ResponseEntity<Map<String, Object>> getGameDetails(
            @PathVariable String gameId
    ) {
        Optional<Map<String, Object>> game = catalogService.getGameById(gameId);

        if (game.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.ok(game.get());
    }

    /**
     * Jeux par éditeur
     * GET /platform/catalog/publishers/{publisherId}/games
     */
    @GetMapping("/publishers/{publisherId}/games")
    public ResponseEntity<Map<String, Object>> getGamesByPublisher(
            @PathVariable String publisherId
    ) {
        List<Map<String, Object>> games = catalogService.getGamesByPublisher(publisherId);

        return ResponseEntity.ok(Map.of(
                "publisherId", publisherId,
                "gameCount", games.size(),
                "games", games
        ));
    }

    /**
     * Nombre de jeux par éditeur
     * GET /platform/catalog/publishers/{publisherId}/count
     */
    @GetMapping("/publishers/{publisherId}/count")
    public ResponseEntity<Map<String, Object>> countGamesByPublisher(
            @PathVariable String publisherId
    ) {
        long count = catalogService.countGamesByPublisher(publisherId);

        return ResponseEntity.ok(Map.of(
                "publisherId", publisherId,
                "gameCount", count
        ));
    }

    /**
     * Jeux par genre
     * GET /platform/catalog/genres/{genre}
     */
    @GetMapping("/genres/{genre}")
    public ResponseEntity<Map<String, Object>> getGamesByGenre(
            @PathVariable GameGenre genre
    ) {
        List<Map<String, Object>> games = catalogService.getGamesByGenre(genre);

        return ResponseEntity.ok(Map.of(
                "genre", genre.name(),
                "gameCount", games.size(),
                "games", games
        ));
    }

    /**
     * Jeux par plateforme
     * GET /platform/catalog/platforms/{platform}
     */
    @GetMapping("/platforms/{platform}")
    public ResponseEntity<Map<String, Object>> getGamesByPlatform(
            @PathVariable ExecPlatform platform
    ) {
        List<Map<String, Object>> games = catalogService.getGamesByPlatform(platform);

        return ResponseEntity.ok(Map.of(
                "platform", platform.name(),
                "gameCount", games.size(),
                "games", games
        ));
    }

}
