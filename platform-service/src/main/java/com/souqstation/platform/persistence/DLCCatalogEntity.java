package com.souqstation.platform.persistence;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "dlc_catalog")
public class DLCCatalogEntity {

    @Id
    @Column(name = "dlc_id", nullable = false, updatable = false)
    private String dlcId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description", length = 2000)
    private String description;

    @Column(name = "publisher_id", nullable = false)
    private String publisherId;

    @Column(name = "price")
    private Double price;

    @Column(name = "release_date", nullable = false)
    private Instant releaseDate;

    @Column(name = "added_at", nullable = false)
    private Instant addedAt;

    // Constructeur par défaut (requis par JPA)
    protected DLCCatalogEntity() {}

    // Constructeur complet
    public DLCCatalogEntity(
            String dlcId,
            String gameId,
            String name,
            String description,
            String publisherId,
            Double price,
            Instant releaseDate,
            Instant addedAt
    ) {
        this.dlcId = dlcId;
        this.gameId = gameId;
        this.name = name;
        this.description = description;
        this.publisherId = publisherId;
        this.price = price;
        this.releaseDate = releaseDate;
        this.addedAt = addedAt;
    }

    // Getters
    public String getDlcId() { return dlcId; }
    public String getGameId() { return gameId; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getPublisherId() { return publisherId; }
    public Double getPrice() { return price; }
    public Instant getReleaseDate() { return releaseDate; }
    public Instant getAddedAt() { return addedAt; }
}
