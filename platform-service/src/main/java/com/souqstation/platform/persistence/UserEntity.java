package com.souqstation.platform.persistence;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "users")
@Inheritance(strategy = InheritanceType.JOINED)
public class UserEntity {

    @Id
    @Column(name = "user_id", nullable = false, length = 64, unique = true)
    private String userId;

    @Column(name = "email", nullable = false, length = 120, unique = true)
    private String email;

    @Column(name = "name", nullable = false, length = 80)
    private String name;

    @Column(name = "display_name", nullable = false, length = 80)
    private String displayName;

    @Column(name = "birth", nullable = false)
    private Date birth;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "solde", nullable = false)
    private float solde;

    protected UserEntity() {}

    public UserEntity(String userId, String email, String name, String displayName, Date birth, Instant createdAt, float solde) {
        this.userId = userId;
        this.email = email;
        this.displayName = displayName;
        this.createdAt = createdAt;
        this.birth = birth;
        this.name = name;
        this.solde = solde;
    }

    @ManyToMany
    @JoinTable(
            name = "user_following",
            joinColumns = @JoinColumn(name = "user_id"),       // celui qui suit
            inverseJoinColumns = @JoinColumn(name = "followed_id") // celui qui est suivi
    )
    private Set<UserEntity> following = new HashSet<>();

    public Set<UserEntity> getFollowing() {
        return following;
    }

    public void follow(UserEntity other) {
        if (other == null) return;
        if (this.userId.equals(other.userId)) return; // éviter soi-même
        this.following.add(other);
    }

    public void unfollow(UserEntity other) {
        if (other == null) return;
        this.following.remove(other);
    }

    public String getUserId() { return userId; }
    public String getEmail() { return email; }
    public String getDisplayName() { return displayName; }
    public Instant getCreatedAt() { return createdAt; }
    public String getName() {
        return name;
    }
    public float getSolde(){return solde;}
    public Date getBirth() {
        return birth;
    }

    // Setter pour le solde (nécessaire pour les achats)
    public void setSolde(float solde) {
        this.solde = solde;
    }

    // Méthode utilitaire pour déduire un montant
    public void deductBalance(double amount) {
        if (amount < 0) {
            throw new IllegalArgumentException("Amount must be positive");
        }
        if (this.solde < amount) {
            throw new IllegalArgumentException("Insufficient balance");
        }
        this.solde -= amount;
    }

}