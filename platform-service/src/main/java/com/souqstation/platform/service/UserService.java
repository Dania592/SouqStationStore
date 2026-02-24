package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformUserEventProducer;
import com.souqstation.platform.persistence.UserEntity;
import com.souqstation.platform.persistence.UserRepository;
import com.souqstation.schemas.events.UserRegistered;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PlatformUserEventProducer producer;

    public UserService(UserRepository userRepository, PlatformUserEventProducer producer) {
        this.userRepository = userRepository;
        this.producer = producer;
    }

    @Transactional
    public UserRegistered registerUser(String userId, String email, String name, String displayName, Date birth, float solde) {
        Instant now = Instant.now();

        if (!userRepository.existsById(userId)) {
            if (userRepository.existsByEmail(email)) {
                throw new IllegalArgumentException("Email already used: " + email);
            }
            userRepository.save(new UserEntity(userId, email,name, displayName, birth, now, solde));
        }

        UserRegistered event = UserRegistered.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(Instant.ofEpochSecond(now.toEpochMilli()))
                .setCreatedAt(Instant.ofEpochSecond(now.toEpochMilli()))
                .setUserId(userId)
                .setEmail(email)
                .setBirth(birth.toInstant())
                .setName(name)
                .setSolde(solde)
                .setDisplayName(displayName)
                .build();

        producer.publishUser(userId, event);

        return event;
    }

    public boolean existsByEmail(String email) {
        return userRepository.existsByEmail(email);
    }

    public String findUserIdByEmail(String email) {
        return userRepository.findByEmail(email)
                .map(UserEntity::getUserId)
                .orElseThrow(() -> new IllegalArgumentException("User not found for email: " + email));
    }
}