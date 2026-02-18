package com.souqstation.platform.api;

import com.souqstation.platform.service.UserService;
import com.souqstation.schemas.events.UserRegistered;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Date;
import java.util.Map;

@RestController
@RequestMapping("/platform")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/register-user")
    public ResponseEntity<Map<String, String>> register(
            @RequestParam String userId,
            @RequestParam String name,
            @RequestParam String email,
            @RequestParam String displayName,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) Date birth
    ) {
        UserRegistered event = userService.registerUser(
                userId, email, name, displayName, birth
        );

        return ResponseEntity.ok(Map.of(
                "status", "USER_REGISTERED",
                "eventId", event.getEventId(),
                "userId", event.getUserId(),
                "email", event.getEmail(),
                "name", event.getName(),
                "displayName", event.getDisplayName(),
                "birth", event.getBirth().toString(),
                "occurredAt", event.getOccurredAt().toString()
        ));
    }
}