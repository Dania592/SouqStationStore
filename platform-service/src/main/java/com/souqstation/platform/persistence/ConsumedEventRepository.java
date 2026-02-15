package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ConsumedEventRepository extends JpaRepository<ConsumedEventEntity, String> {}