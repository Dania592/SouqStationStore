package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformPurchaseEventProducer;
import com.souqstation.platform.persistence.*;
import com.souqstation.schemas.events.GamePurchasedEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class PurchaseService {

    private final GamePurchaseRepository gamePurchaseRepository;
    private final UserRepository userRepository;
    private final GameCatalogRepository gameCatalogRepository;
    private final PlatformPurchaseEventProducer producer;

    public PurchaseService(
            GamePurchaseRepository gamePurchaseRepository,
            UserRepository userRepository,
            GameCatalogRepository gameCatalogRepository,
            PlatformPurchaseEventProducer producer
    ) {
        this.gamePurchaseRepository = gamePurchaseRepository;
        this.userRepository = userRepository;
        this.gameCatalogRepository = gameCatalogRepository;
        this.producer = producer;
    }

    @Transactional
    public GamePurchasedEvent purchaseGame(String userId, String gameId) {
        Instant now = Instant.now();

        // 1) Vérifier que l'utilisateur existe
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        // 2) Vérifier que le jeu existe dans le catalogue
        GameCatalogEntity game = gameCatalogRepository.findById(gameId)
                .orElseThrow(() -> new IllegalArgumentException("Game not found in catalog: " + gameId));

        // 3) Vérifier que l'utilisateur ne possède pas déjà le jeu
        if (gamePurchaseRepository.existsByUserIdAndGameId(userId, gameId)) {
            throw new IllegalArgumentException("User already owns this game: " + gameId);
        }

        // 4) Vérifier que le jeu a un prix
        if (game.getPrice() == null || game.getPrice() <= 0) {
            throw new IllegalArgumentException("Game has no valid price: " + gameId);
        }

        // 5) Vérifier le solde de l'utilisateur
        if (user.getSolde() < game.getPrice()) {
            throw new IllegalArgumentException(
                    String.format("Insufficient balance. Required: %.2f€, Available: %.2f€",
                            game.getPrice(), user.getSolde())
            );
        }

        // 6) Déduire le montant du solde de l'utilisateur
        user.deductBalance(game.getPrice());
        userRepository.save(user);

        // 7) Créer l'achat
        String purchaseId = UUID.randomUUID().toString();
        GamePurchaseEntity purchase = new GamePurchaseEntity(
                purchaseId,
                userId,
                gameId,
                game.getName(),
                game.getPublisherId(),
                game.getPrice(),
                now
        );

        gamePurchaseRepository.save(purchase);

        // 8) Créer l'événement Avro
        GamePurchasedEvent event = GamePurchasedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setPurchaseId(purchaseId)
                .setUserId(userId)
                .setGameId(gameId)
                .setGameName(game.getName())
                .setPublisherId(game.getPublisherId())
                .setPrice(game.getPrice())
                .setPurchasedAt(now)
                .build();

        // 9) Publier vers Kafka
        producer.publishPurchase(userId, event);

        return event;
    }

    public List<Map<String, Object>> getUserLibrary(String userId) {
        // Vérifier que l'utilisateur existe
        if (!userRepository.existsById(userId)) {
            throw new IllegalArgumentException("User not found: " + userId);
        }

        List<GamePurchaseEntity> purchases = gamePurchaseRepository.findByUserId(userId);

        return purchases.stream()
                .map(p -> Map.<String, Object>of(
                        "purchaseId", p.getPurchaseId(),
                        "gameId", p.getGameId(),
                        "gameName", p.getGameName(),
                        "publisherId", p.getPublisherId(),
                        "price", p.getPrice(),
                        "purchasedAt", p.getPurchasedAt().toString()
                ))
                .collect(Collectors.toList());
    }

    public boolean userOwnsGame(String userId, String gameId) {
        return gamePurchaseRepository.existsByUserIdAndGameId(userId, gameId);
    }

    public long getGameSalesCount(String gameId) {
        return gamePurchaseRepository.countByGameId(gameId);
    }
}
