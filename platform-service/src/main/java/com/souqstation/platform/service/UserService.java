package com.souqstation.platform.service;

import com.souqstation.platform.persistence.UserEntity;
import com.souqstation.platform.persistence.UserRepository;
import com.souqstation.platform.messaging.PlatformEventProducer;
import com.souqstation.shared.events.EventEnvelope;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Map;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PlatformEventProducer producer;

    public UserService(UserRepository userRepository, PlatformEventProducer producer) {
        this.userRepository = userRepository;
        this.producer = producer;
    }

    @Transactional
    public EventEnvelope registerUser(String userId, String email, String displayName) {
        if (userRepository.existsById(userId)) {
            // Idempotent côté API: si user existe déjà, on renvoie un event "dummy" ou on renvoie l'existant
            // Ici: on renvoie un event UserRegistered quand même (option) OU on renvoie un message.
            // Pour rester simple: on renvoie un event mais sans réécrire DB.
        } else {
            if (userRepository.existsByEmail(email)) {
                throw new IllegalArgumentException("Email already used: " + email);
            }
            userRepository.save(new UserEntity(userId, email, displayName, Instant.now()));
        }

        EventEnvelope event = EventEnvelope.of(
                "UserRegistered",
                Map.of("userId", userId, "email", email, "displayName", displayName)
        );

        // key = userId
        producer.publish(userId, event);
        return event;
    }
}