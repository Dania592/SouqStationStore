package com.souqstation.platform.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "dlc_catalog")
public class DlcEntity {

    @Id
    @Column(name = "dlc_id", nullable = false, updatable = false)
    private String dlcId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description")
    private String description;

    @Column(name = "publisher_id", nullable = false)
    private String publisherId;

    @Column(name = "price")
    private Double price;

    @Column(name = "release_date")
    private Instant releaseDate;

    protected DlcEntity() {
    }

    public DlcEntity(
            String dlcId,
            String gameId,
            String name,
            String description,
            String publisherId,
            Double price,
            Instant releaseDate) {
        this.dlcId = dlcId;
        this.gameId = gameId;
        this.name = name;
        this.description = description;
        this.publisherId = publisherId;
        this.price = price;
        this.releaseDate = releaseDate;
    }

    public String getDlcId() {
        return dlcId;
    }

    public String getGameId() {
        return gameId;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public String getPublisherId() {
        return publisherId;
    }

    public Double getPrice() {
        return price;
    }

    public Instant getReleaseDate() {
        return releaseDate;
    }
}
