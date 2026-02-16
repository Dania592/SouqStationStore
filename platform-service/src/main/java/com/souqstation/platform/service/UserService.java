package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformUserEventProducer;
import com.souqstation.platform.persistence.UserEntity;
import com.souqstation.platform.persistence.UserRepository;
import com.souqstation.schemas.events.UserRegistered;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
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
    public UserRegistered registerUser(String userId, String email, String displayName) {
        Instant now = Instant.now();

        if (!userRepository.existsById(userId)) {
            if (userRepository.existsByEmail(email)) {
                throw new IllegalArgumentException("Email already used: " + email);
            }
            userRepository.save(new UserEntity(userId, email, displayName, now));
        }

        UserRegistered event = UserRegistered.newBuilder()
                .setEventId(UUID.randomUUID().toString())
                .setOccurredAt(Instant.ofEpochSecond(now.toEpochMilli()))
                .setSchemaVersion(1)
                .setUserId(userId)
                .setEmail(email)
                .setDisplayName(displayName)
                .build();

        producer.publish(userId, event);
        return event;
    }
}