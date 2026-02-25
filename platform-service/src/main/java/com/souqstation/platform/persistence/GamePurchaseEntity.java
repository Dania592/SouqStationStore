package com.souqstation.platform.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "game_purchases")
public class GamePurchaseEntity {

    @Id
    @Column(name = "purchase_id", nullable = false, updatable = false)
    private String purchaseId;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "game_name", nullable = false)
    private String gameName;

    @Column(name = "publisher_id", nullable = false)
    private String publisherId;

    @Column(name = "price", nullable = false)
    private Double price;

    @Column(name = "purchased_at", nullable = false)
    private Instant purchasedAt;

    protected GamePurchaseEntity() {}

    public GamePurchaseEntity(
            String purchaseId,
            String userId,
            String gameId,
            String gameName,
            String publisherId,
            Double price,
            Instant purchasedAt
    ) {
        this.purchaseId = purchaseId;
        this.userId = userId;
        this.gameId = gameId;
        this.gameName = gameName;
        this.publisherId = publisherId;
        this.price = price;
        this.purchasedAt = purchasedAt;
    }

    public String getPurchaseId() { return purchaseId; }
    public String getUserId() { return userId; }
    public String getGameId() { return gameId; }
    public String getGameName() { return gameName; }
    public String getPublisherId() { return publisherId; }
    public Double getPrice() { return price; }
    public Instant getPurchasedAt() { return purchasedAt; }
}
