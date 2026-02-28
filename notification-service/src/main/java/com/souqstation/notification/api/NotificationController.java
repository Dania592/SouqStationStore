package com.souqstation.notification.api;

import com.souqstation.notification.persistence.entity.NotificationEntity;
import com.souqstation.notification.persistence.repo.NotificationRepository;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/notifications")
public class NotificationController {

    private final NotificationRepository notificationRepository;

    public NotificationController(NotificationRepository notificationRepository) {
        this.notificationRepository = notificationRepository;
    }

    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    @GetMapping("/{userId}")
    public List<NotificationEntity> last(@PathVariable String userId) {
        return notificationRepository.findTop50ByUserIdOrderByCreatedAtDesc(userId);
    }

    @PostMapping("/send")
    public NotificationEntity send(
            @RequestParam String userId,
            @RequestParam String type,
            @RequestParam String message) {

        NotificationEntity notif = new NotificationEntity(
                java.util.UUID.randomUUID().toString(),
                userId,
                type,
                message,
                java.time.Instant.now(),
                "manual-" + java.util.UUID.randomUUID().toString());
        return notificationRepository.save(notif);
    }
}