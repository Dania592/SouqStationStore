package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformUserEventProducer;
import com.souqstation.platform.persistence.RedactorEntity;
import com.souqstation.platform.persistence.RedactorRepository;
import com.souqstation.schemas.events.RedactorRegisteredEvent;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Service
public class RedactorService {

    private final RedactorRepository redactorRepository;
    private final PlatformUserEventProducer producer;

    public RedactorService(RedactorRepository redactorRepository, PlatformUserEventProducer producer) {
        this.redactorRepository = redactorRepository;
        this.producer = producer;
    }

    @Transactional
    public RedactorRegisteredEvent registerRedactor(
            String userId,
            String email,
            String name,
            String displayName,
            Date birth,
            float solde,
            boolean individual
    ) {
        Instant now = Instant.now();

        if (!redactorRepository.existsById(userId)) {
            if (redactorRepository.existsByEmail(email)) {
                throw new IllegalArgumentException("Email already used: " + email);
            }
            redactorRepository.save(new RedactorEntity(
                    userId,
                    email,
                    name,
                    displayName,
                    birth,
                    now,
                    solde,
                    individual));
        }

        RedactorRegisteredEvent event = RedactorRegisteredEvent.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(Instant.ofEpochSecond(now.toEpochMilli()))
                .setCreatedAt(Instant.ofEpochSecond(now.toEpochMilli()))
                .setUserId(userId)
                .setEmail(email)
                .setBirth(birth.toInstant())
                .setName(name)
                .setDisplayName(displayName)
                .setSolde(solde)
                .setIndividual(individual)
                .build();

        producer.publishRedactor(userId, event);

        return event;
    }
    public boolean existsById(String userId) {
        return redactorRepository.existsById(userId);
    }


}
