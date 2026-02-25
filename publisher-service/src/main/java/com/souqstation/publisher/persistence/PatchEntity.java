package com.souqstation.publisher.persistence;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "patches")
public class PatchEntity {

    @Id
    @Column(name = "patch_id", nullable = false, updatable = false)
    private String patchId;

    @Column(name = "game_id", nullable = false)
    private String gameId;

    @Column(name = "previous_version", nullable = false)
    private String previousVersion;

    @Column(name = "target_version", nullable = false)
    private String targetVersion;

    @Column(name = "description", length = 2000)
    private String description;

    @ElementCollection
    @CollectionTable(name = "patch_modifications", joinColumns = @JoinColumn(name = "patch_id"))
    @Column(name = "modification_type")
    @Enumerated(EnumType.STRING)
    private List<ModificationType> modifications = new ArrayList<>();

    @Column(name = "released_at", nullable = false)
    private Instant releasedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    // Constructeur par défaut (requis par JPA)
    protected PatchEntity() {}

    // Constructeur complet
    public PatchEntity(
            String patchId,
            String gameId,
            String previousVersion,
            String targetVersion,
            String description,
            List<ModificationType> modifications,
            Instant releasedAt,
            Instant createdAt
    ) {
        this.patchId = patchId;
        this.gameId = gameId;
        this.previousVersion = previousVersion;
        this.targetVersion = targetVersion;
        this.description = description;
        this.modifications = modifications != null ? modifications : new ArrayList<>();
        this.releasedAt = releasedAt;
        this.createdAt = createdAt;
    }

    // Enum pour les types de modification
    public enum ModificationType {
        CORRECTION,
        AJOUT,
        OPTIMISATION
    }

    // Getters
    public String getPatchId() { return patchId; }
    public String getGameId() { return gameId; }
    public String getPreviousVersion() { return previousVersion; }
    public String getTargetVersion() { return targetVersion; }
    public String getDescription() { return description; }
    public List<ModificationType> getModifications() { return modifications; }
    public Instant getReleasedAt() { return releasedAt; }
    public Instant getCreatedAt() { return createdAt; }
}
