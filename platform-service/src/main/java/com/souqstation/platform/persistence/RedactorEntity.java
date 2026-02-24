package com.souqstation.platform.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.Date;

@Entity
@Table(name = "redactors")
public class RedactorEntity extends UserEntity {

    @Column(name = "individual", nullable = false)
    private Boolean individual;

    protected RedactorEntity() {}

    public RedactorEntity(
            String userId,
            String email,
            String name,
            String displayName,
            Date birth,
            Instant createdAt,
            float solde,
            boolean individual
    ) {
        super(userId, email, name, displayName, birth, createdAt, solde);
        this.individual = individual;
    }

    public boolean isIndividual(){return individual;}
}