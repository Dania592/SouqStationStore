package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.UUID;

public interface ConsumedEventRepository extends JpaRepository<ConsumedEventEntity, UUID> {}