package com.souqstation.platform.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "dlc_purchases")
public class DLCPurchaseEntity {

    @Id
    @Column(name = "purchase_id", nullable = false, updatable = false)
    private String purchaseId;

    @Column(name = "user_id", nullable = false)
    private String userId;

    @Column(name = "dlc_id", nullable = false)
    private String dlcId;

    @Column(name = "dlc_name", nullable = false)
    private String dlcName;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "publisher_id", nullable = false)
    private String publisherId;

    @Column(name = "price", nullable = false)
    private double price;

    @Column(name = "purchased_at", nullable = false)
    private Instant purchasedAt;

    // Constructeur par défaut (requis par JPA)
    protected DLCPurchaseEntity() {}

    // Constructeur complet
    public DLCPurchaseEntity(
            String purchaseId,
            String userId,
            String dlcId,
            String dlcName,
            String gameId,
            String publisherId,
            double price,
            Instant purchasedAt
    ) {
        this.purchaseId = purchaseId;
        this.userId = userId;
        this.dlcId = dlcId;
        this.dlcName = dlcName;
        this.gameId = gameId;
        this.publisherId = publisherId;
        this.price = price;
        this.purchasedAt = purchasedAt;
    }

    // Getters
    public String getPurchaseId() { return purchaseId; }
    public String getUserId() { return userId; }
    public String getDlcId() { return dlcId; }
    public String getDlcName() { return dlcName; }
    public String getGameId() { return gameId; }
    public String getPublisherId() { return publisherId; }
    public double getPrice() { return price; }
    public Instant getPurchasedAt() { return purchasedAt; }
}
