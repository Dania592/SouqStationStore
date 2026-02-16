package com.souqstation.platform.api;

import com.souqstation.platform.service.UserService;
import com.souqstation.schemas.events.UserRegistered;
import com.souqstation.shared.events.EventEnvelope;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/platform")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping("/users")
    public UserRegistered register(
            @RequestParam String userId,
            @RequestParam String email,
            @RequestParam String displayName
    ) {
        return userService.registerUser(userId, email, displayName);
    }

    @GetMapping("/users/register")
    public UserRegistered registerGet(
            @RequestParam String userId,
            @RequestParam String email,
            @RequestParam String displayName
    ) {
        return userService.registerUser(userId, email, displayName);
    }
}