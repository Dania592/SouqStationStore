package com.souqstation.platform.persistence;

import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "game_catalog")
public class GameCatalogEntity {

    @Id
    @Column(name = "game_id", nullable = false, updatable = false)
    private String gameId;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description")
    private String description;

    @Column(name = "publisher_id", nullable = false)
    private String publisherId;

    @Enumerated(EnumType.STRING)
    @Column(name = "platform_exc", nullable = false)
    private ExecPlatform platformExc;

    @Enumerated(EnumType.STRING)
    @Column(name = "genre", nullable = false)
    private GameGenre genre;

    @Column(name = "version", nullable = false)
    private String version;

    @Column(name = "price")
    private Double price;

    @Column(name = "release_date", nullable = false)
    private Instant releaseDate;

    @Column(name = "added_at", nullable = false)
    private Instant addedAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    protected GameCatalogEntity() {}

    public GameCatalogEntity(
            String gameId,
            String name,
            String description,
            String publisherId,
            ExecPlatform platformExc,
            GameGenre genre,
            String version,
            Double price,
            Instant releaseDate,
            Instant addedAt
    ) {
        this.gameId = gameId;
        this.name = name;
        this.description = description;
        this.publisherId = publisherId;
        this.platformExc = platformExc;
        this.genre = genre;
        this.version = version;
        this.price = price;
        this.releaseDate = releaseDate;
        this.addedAt = addedAt;
        this.updatedAt = addedAt;
    }

    // Méthode pour mettre à jour la version (lors d'un patch)
    public void updateVersion(String newVersion) {
        this.version = newVersion;
        this.updatedAt = Instant.now();
    }

    // Getters
    public String getGameId() { return gameId; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getPublisherId() { return publisherId; }
    public ExecPlatform getPlatformExc() { return platformExc; }
    public GameGenre getGenre() { return genre; }
    public String getVersion() { return version; }
    public Double getPrice() { return price; }
    public Instant getReleaseDate() { return releaseDate; }
    public Instant getAddedAt() { return addedAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    // Setters pour permettre la mise à jour
    public void setPrice(Double price) {
        this.price = price;
        this.updatedAt = Instant.now();
    }

    public void setDescription(String description) {
        this.description = description;
        this.updatedAt = Instant.now();
    }
}
