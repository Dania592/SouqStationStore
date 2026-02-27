package com.souqstation.publisher.persistence;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "dlcs")
public class DlcEntity {

    @Id
    private String dlcId;

    private String gameId;
    private String name;
    private String description;

    private String publisherId;
    private Double price;

    private Instant releaseDate;
    private Instant createdAt;

    public DlcEntity() {}

    public DlcEntity(String dlcId, String gameId, String name, String description,
                     String publisherId, Double price, Instant releaseDate, Instant createdAt) {
        this.dlcId = dlcId;
        this.gameId = gameId;
        this.name = name;
        this.description = description;
        this.publisherId = publisherId;
        this.price = price;
        this.releaseDate = releaseDate;
        this.createdAt = createdAt;
    }

    public String getDlcId() { return dlcId; }
    public String getGameId() { return gameId; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getPublisherId() { return publisherId; }
    public Double getPrice() { return price; }
    public Instant getReleaseDate() { return releaseDate; }
    public Instant getCreatedAt() { return createdAt; }

    public void setDlcId(String dlcId) { this.dlcId = dlcId; }
    public void setGameId(String gameId) { this.gameId = gameId; }
    public void setName(String name) { this.name = name; }
    public void setDescription(String description) { this.description = description; }
    public void setPublisherId(String publisherId) { this.publisherId = publisherId; }
    public void setPrice(Double price) { this.price = price; }
    public void setReleaseDate(Instant releaseDate) { this.releaseDate = releaseDate; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}