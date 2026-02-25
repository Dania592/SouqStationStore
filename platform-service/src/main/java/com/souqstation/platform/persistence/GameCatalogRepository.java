package com.souqstation.platform.persistence;

import com.souqstation.schemas.common.ExecPlatform;
import com.souqstation.schemas.common.GameGenre;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface GameCatalogRepository extends JpaRepository<GameCatalogEntity, String> {
    
    List<GameCatalogEntity> findByPublisherId(String publisherId);
    
    List<GameCatalogEntity> findByGenre(GameGenre genre);
    
    List<GameCatalogEntity> findByPlatformExc(ExecPlatform platform);
    
    List<GameCatalogEntity> findByGenreAndPlatformExc(GameGenre genre, ExecPlatform platform);
    
    List<GameCatalogEntity> findByPriceLessThanEqual(Double maxPrice);
    
    long countByPublisherId(String publisherId);
}
