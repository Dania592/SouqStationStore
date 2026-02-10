package com.souqstation.platform.api;

import com.souqstation.platform.service.UserService;
import com.souqstation.shared.events.EventEnvelope;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/platform")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    // POST recommandé (propre). Tu peux aussi ajouter GET si tu veux tester vite.
    @PostMapping("/users")
    public EventEnvelope register(
            @RequestParam String userId,
            @RequestParam String email,
            @RequestParam String displayName
    ) {
        return userService.registerUser(userId, email, displayName);
    }

    // Optionnel pour tester rapidement en navigateur
    @GetMapping("/users/register")
    public EventEnvelope registerGet(
            @RequestParam String userId,
            @RequestParam String email,
            @RequestParam String displayName
    ) {
        return userService.registerUser(userId, email, displayName);
    }
}