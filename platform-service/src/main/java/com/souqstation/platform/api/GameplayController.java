package com.souqstation.platform.api;

import com.souqstation.platform.persistence.GamePlaySessionEntity;
import com.souqstation.platform.service.GameplayService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/platform/sessions")
public class GameplayController {

    private final GameplayService gameplayService;

    public GameplayController(GameplayService gameplayService) {
        this.gameplayService = gameplayService;
    }

    @PostMapping("/start")
    public ResponseEntity<GamePlaySessionEntity> start(
            @RequestParam String userId,
            @RequestParam String gameId
    ) {
        return ResponseEntity.ok(gameplayService.startSession(userId, gameId));
    }

    @PostMapping("/end")
    public ResponseEntity<GamePlaySessionEntity> end(
            @RequestParam String userId,
            @RequestParam String gameId
    ) {
        return ResponseEntity.ok(gameplayService.endSession(userId, gameId));
    }

    @GetMapping("/users/{userId}/playtime")
    public ResponseEntity<Map<String, Object>> playtime(
            @PathVariable String userId,
            @RequestParam(required = false) String gameId
    ) {
        long total = gameplayService.getTotalPlaytimeSeconds(userId, gameId);
        return ResponseEntity.ok(Map.of(
                "userId", userId,
                "gameId", gameId,
                "totalSeconds", total
        ));
    }
}