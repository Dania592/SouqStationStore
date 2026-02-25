package com.souqstation.platform.api;

import com.souqstation.platform.service.PurchaseService;
import com.souqstation.schemas.events.DLCPurchasedEvent;
import com.souqstation.schemas.events.GamePurchasedEvent;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/platform/purchases")
public class PurchaseController {

    private final PurchaseService purchaseService;

    public PurchaseController(PurchaseService purchaseService) {
        this.purchaseService = purchaseService;
    }

    /**
     * Acheter un jeu
     * POST /platform/purchases/game?userId=U1&gameId=G1
     */
    @PostMapping("/game")
    public ResponseEntity<Map<String, Object>> purchaseGame(
            @RequestParam String userId,
            @RequestParam String gameId
    ) {
        try {
            GamePurchasedEvent event = purchaseService.purchaseGame(userId, gameId);

            return ResponseEntity.ok(Map.of(
                    "status", "PURCHASE_SUCCESS",
                    "eventId", event.getEventId(),
                    "purchaseId", event.getPurchaseId(),
                    "userId", event.getUserId(),
                    "gameId", event.getGameId(),
                    "gameName", event.getGameName(),
                    "price", event.getPrice(),
                    "purchasedAt", event.getPurchasedAt().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "PURCHASE_FAILED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Récupérer la bibliothèque d'un utilisateur
     * GET /platform/purchases/library?userId=U1
     */
    @GetMapping("/library")
    public ResponseEntity<Map<String, Object>> getUserLibrary(
            @RequestParam String userId
    ) {
        try {
            List<Map<String, Object>> library = purchaseService.getUserLibrary(userId);

            return ResponseEntity.ok(Map.of(
                    "userId", userId,
                    "gameCount", library.size(),
                    "games", library
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "ERROR",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Vérifier si un utilisateur possède un jeu
     * GET /platform/purchases/owns?userId=U1&gameId=G1
     */
    @GetMapping("/owns")
    public ResponseEntity<Map<String, Object>> userOwnsGame(
            @RequestParam String userId,
            @RequestParam String gameId
    ) {
        boolean owns = purchaseService.userOwnsGame(userId, gameId);

        return ResponseEntity.ok(Map.of(
                "userId", userId,
                "gameId", gameId,
                "owns", owns
        ));
    }

    /**
     * Nombre de ventes d'un jeu
     * GET /platform/purchases/sales-count?gameId=G1
     */
    @GetMapping("/sales-count")
    public ResponseEntity<Map<String, Object>> getGameSalesCount(
            @RequestParam String gameId
    ) {
        long count = purchaseService.getGameSalesCount(gameId);

        return ResponseEntity.ok(Map.of(
                "gameId", gameId,
                "salesCount", count
        ));
    }

    /**
     * Acheter un DLC
     * POST /platform/purchases/dlc?userId=U1&dlcId=DLC1
     */
    @PostMapping("/dlc")
    public ResponseEntity<Map<String, Object>> purchaseDLC(
            @RequestParam String userId,
            @RequestParam String dlcId
    ) {
        try {
            DLCPurchasedEvent event = purchaseService.purchaseDLC(userId, dlcId);

            return ResponseEntity.ok(Map.of(
                    "status", "DLC_PURCHASE_SUCCESS",
                    "eventId", event.getEventId(),
                    "purchaseId", event.getPurchaseId(),
                    "userId", event.getUserId(),
                    "dlcId", event.getDlcId(),
                    "dlcName", event.getDlcName(),
                    "gameId", event.getGameId(),
                    "price", event.getPrice(),
                    "purchasedAt", event.getPurchasedAt().toString()
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "DLC_PURCHASE_FAILED",
                    "reason", e.getMessage()
            ));
        }
    }

    /**
     * Récupérer les DLC possédés par un utilisateur
     * GET /platform/purchases/dlcs?userId=U1
     */
    @GetMapping("/dlcs")
    public ResponseEntity<Map<String, Object>> getUserDLCs(
            @RequestParam String userId
    ) {
        try {
            List<Map<String, Object>> dlcs = purchaseService.getUserDLCs(userId);

            return ResponseEntity.ok(Map.of(
                    "userId", userId,
                    "dlcCount", dlcs.size(),
                    "dlcs", dlcs
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "status", "ERROR",
                    "reason", e.getMessage()
            ));
        }
    }
}
