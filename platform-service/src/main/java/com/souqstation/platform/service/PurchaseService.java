package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformDLCPurchaseEventProducer;
import com.souqstation.platform.messaging.PlatformPurchaseEventProducer;
import com.souqstation.platform.persistence.*;
import com.souqstation.schemas.events.DLCPurchasedEvent;
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
    private final DLCPurchaseRepository dlcPurchaseRepository;
    private final UserRepository userRepository;
    private final GameCatalogRepository gameCatalogRepository;
    private final DLCCatalogRepository dlcCatalogRepository;
    private final PlatformPurchaseEventProducer producer;
    private final PlatformDLCPurchaseEventProducer dlcProducer;

    public PurchaseService(
            GamePurchaseRepository gamePurchaseRepository,
            DLCPurchaseRepository dlcPurchaseRepository,
            UserRepository userRepository,
            GameCatalogRepository gameCatalogRepository,
            DLCCatalogRepository dlcCatalogRepository,
            PlatformPurchaseEventProducer producer,
            PlatformDLCPurchaseEventProducer dlcProducer
    ) {
        this.gamePurchaseRepository = gamePurchaseRepository;
        this.dlcPurchaseRepository = dlcPurchaseRepository;
        this.userRepository = userRepository;
        this.gameCatalogRepository = gameCatalogRepository;
        this.dlcCatalogRepository = dlcCatalogRepository;
        this.producer = producer;
        this.dlcProducer = dlcProducer;
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

    @Transactional
    public DLCPurchasedEvent purchaseDLC(String userId, String dlcId) {
        Instant now = Instant.now();

        // 1) Vérifier que l'utilisateur existe
        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        // 2) Vérifier que le DLC existe dans le catalogue
        DLCCatalogEntity dlc = dlcCatalogRepository.findById(dlcId)
                .orElseThrow(() -> new IllegalArgumentException("DLC not found in catalog: " + dlcId));

        // 3) Vérifier que l'utilisateur possède le jeu parent
        if (!gamePurchaseRepository.existsByUserIdAndGameId(userId, dlc.getGameId())) {
            throw new IllegalArgumentException("User must own the base game to purchase this DLC: " + dlc.getGameId());
        }

        // 4) Vérifier que l'utilisateur ne possède pas déjà le DLC
        if (dlcPurchaseRepository.existsByUserIdAndDlcId(userId, dlcId)) {
            throw new IllegalArgumentException("User already owns this DLC: " + dlcId);
        }

        // 5) Vérifier que le DLC a un prix
        if (dlc.getPrice() == null || dlc.getPrice() <= 0) {
            throw new IllegalArgumentException("DLC has no valid price: " + dlcId);
        }

        // 6) Vérifier le solde de l'utilisateur
        if (user.getSolde() < dlc.getPrice()) {
            throw new IllegalArgumentException(
                    String.format("Insufficient balance. Required: %.2f€, Available: %.2f€",
                            dlc.getPrice(), user.getSolde())
            );
        }

        // 7) Déduire le montant du solde de l'utilisateur
        user.deductBalance(dlc.getPrice());
        userRepository.save(user);

        // 8) Créer l'achat
        String purchaseId = UUID.randomUUID().toString();
        DLCPurchaseEntity purchase = new DLCPurchaseEntity(
                purchaseId,
                userId,
                dlcId,
                dlc.getName(),
                dlc.getGameId(),
                dlc.getPublisherId(),
                dlc.getPrice(),
                now
        );

        dlcPurchaseRepository.save(purchase);

        // 9) Créer l'événement Avro
        DLCPurchasedEvent event = DLCPurchasedEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(now)
                .setSchemaVersion(1)
                .setPurchaseId(purchaseId)
                .setUserId(userId)
                .setDlcId(dlcId)
                .setDlcName(dlc.getName())
                .setGameId(dlc.getGameId())
                .setPublisherId(dlc.getPublisherId())
                .setPrice(dlc.getPrice())
                .setPurchasedAt(now)
                .build();

        // 10) Publier vers Kafka
        dlcProducer.publishDLCPurchase(userId, event);

        return event;
    }

    public List<Map<String, Object>> getUserDLCs(String userId) {
        if (!userRepository.existsById(userId)) {
            throw new IllegalArgumentException("User not found: " + userId);
        }

        List<DLCPurchaseEntity> dlcPurchases = dlcPurchaseRepository.findByUserId(userId);

        return dlcPurchases.stream()
                .map(d -> Map.<String, Object>of(
                        "purchaseId", d.getPurchaseId(),
                        "dlcId", d.getDlcId(),
                        "dlcName", d.getDlcName(),
                        "gameId", d.getGameId(),
                        "publisherId", d.getPublisherId(),
                        "price", d.getPrice(),
                        "purchasedAt", d.getPurchasedAt().toString()
                ))
                .collect(Collectors.toList());
    }
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
