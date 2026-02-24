package com.souqstation.publisher.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface GameRepository extends JpaRepository<GameEntity, String> {

    boolean existsByGameId(String gameId);

    List<GameEntity> findByPublisherId(String publisherId);
}