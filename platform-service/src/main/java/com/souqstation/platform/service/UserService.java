package com.souqstation.platform.service;

import com.souqstation.platform.messaging.PlatformUserEventProducer;
import com.souqstation.platform.persistence.UserEntity;
import com.souqstation.platform.persistence.UserRepository;
import com.souqstation.schemas.events.UserRegistered;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PlatformUserEventProducer producer;
    private final RedactorService redactorService;

    public UserService(UserRepository userRepository, PlatformUserEventProducer producer, RedactorService redactorService) {
        this.userRepository = userRepository;
        this.producer = producer;
        this.redactorService = redactorService;
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
                .setOccurredAt(now)
                .setCreatedAt(now)
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

    @Transactional
    public void followUser(String userId, String followedId) {

        if (userId.equals(followedId)) {
            throw new IllegalArgumentException("Cannot follow yourself");
        }

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        UserEntity followed = userRepository.findById(followedId)
                .orElseThrow(() -> new IllegalArgumentException("Target not found: " + followedId));

        user.follow(followed);
        userRepository.save(user);
    }

    @Transactional
    public void unfollowUser(String userId, String followedId) {

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        UserEntity followed = userRepository.findById(followedId)
                .orElseThrow(() -> new IllegalArgumentException("Target not found: " + followedId));

        user.unfollow(followed);
        userRepository.save(user);
    }

    public List<Map<String, String>> getFollowing(String userId) {

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        return user.getFollowing().stream()
                .map(u -> Map.of(
                        "userId", u.getUserId(),
                        "displayName", u.getDisplayName()
                ))
                .toList();
    }

    public int countFollowing(String userId) {
        return userRepository.findById(userId)
                .orElseThrow()
                .getFollowing()
                .size();
    }

    @Transactional
    public void followRedactor(String userId, String redactorId) {

        if (userId.equals(redactorId)) {
            throw new IllegalArgumentException("Cannot follow yourself");
        }

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // vérifier que c’est bien un redactor
        if (!redactorService.existsById(redactorId)) {
            throw new IllegalArgumentException("Target is not a redactor");
        }

        UserEntity redactor = userRepository.findById(redactorId)
                .orElseThrow(() -> new IllegalArgumentException("Redactor not found"));

        user.follow(redactor);
        userRepository.save(user);
    }

    public List<Map<String, String>> getFollowedRedactors(String userId) {

        UserEntity user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        return user.getFollowing().stream()
                .filter(u -> redactorService.existsById(u.getUserId()))
                .map(u -> Map.of(
                        "userId", u.getUserId(),
                        "displayName", u.getDisplayName()
                ))
                .toList();
    }
}