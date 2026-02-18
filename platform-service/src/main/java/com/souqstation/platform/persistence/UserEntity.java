package com.souqstation.platform.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Date;

@Entity
@Table(name = "users")
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


    protected UserEntity() {}

    public UserEntity(String userId, String email, String name, String displayName, Date birth, Instant createdAt) {
        this.userId = userId;
        this.email = email;
        this.displayName = displayName;
        this.createdAt = createdAt;
        this.birth = birth;
        this.name = name;
    }

    public String getUserId() { return userId; }
    public String getEmail() { return email; }
    public String getDisplayName() { return displayName; }
    public Instant getCreatedAt() { return createdAt; }
    public String getName() {
        return name;
    }

    public Date getBirth() {
        return birth;
    }

}