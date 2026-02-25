package com.souqstation.platform.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

public interface RedactorRepository extends JpaRepository<RedactorEntity, String> {

    boolean existsByEmail(String email);

}