package com.souqstation.platform.api;

import com.souqstation.platform.service.RedactorService;
import com.souqstation.platform.service.UserService;
import com.souqstation.schemas.events.UserRegistered;
import com.souqstation.schemas.events.RedactorRegisteredEvent;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Date;
import java.util.Map;

@RestController
@RequestMapping("/platform")
public class UserController {

    private final UserService userService;
    private final RedactorService redactorService;

    public UserController(UserService userService, RedactorService redactorService) {
        this.userService = userService;
        this.redactorService = redactorService;
    }

    @PostMapping("/register-user")
    public ResponseEntity<Map<String, String>> register(
            @RequestParam String userId,
            @RequestParam String name,
            @RequestParam String email,
            @RequestParam String displayName,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date birth,
            @RequestParam float solde
    ) {
        UserRegistered event = userService.registerUser(
                userId, email, name, displayName, birth, solde
        );

        return ResponseEntity.ok(Map.<String, String>of(
                "status", "USER_REGISTERED",
                "eventId", event.getEventId(),
                "userId", event.getUserId(),
                "email", event.getEmail(),
                "name", event.getName(),
                "displayName", event.getDisplayName(),
                "birth", event.getBirth().toString(),
                "occurredAt", event.getOccurredAt().toString(),
                "solde", String.valueOf(event.getSolde())
        ));
    }


    @PostMapping("/register-redactor")
    public ResponseEntity<Map<String, String>> registerRedactor(
            @RequestParam String userId,
            @RequestParam String name,
            @RequestParam String email,
            @RequestParam String displayName,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date birth,
            @RequestParam float solde,
            @RequestParam Boolean individual
    ) {
        RedactorRegisteredEvent event = redactorService.registerRedactor(
                userId, email, name, displayName, birth,solde, individual
        );

        return ResponseEntity.ok(Map.of(
                "status", "REDACTOR_REGISTERED",
                "eventId", event.getEventId(),
                "userId", event.getUserId(),
                "email", event.getEmail(),
                "name", event.getName(),
                "displayName", event.getDisplayName(),
                "birth", event.getBirth().toString(),
                "occurredAt", event.getOccurredAt().toString(),
                "solde" ,String.valueOf(event.getSolde()),
                "individual", String.valueOf(event.getIndividual())
        ));
    }
}