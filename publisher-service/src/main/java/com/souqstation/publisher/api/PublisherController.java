package com.souqstation.publisher.api;

import com.souqstation.publisher.messaging.PublisherEventProducer;
import com.souqstation.shared.events.EventEnvelope;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/publisher")
public class PublisherController {

    private final PublisherEventProducer producer;

    public PublisherController(PublisherEventProducer producer) {
        this.producer = producer;
    }

    @RequestMapping(value = "/publish-game", method = {RequestMethod.POST, RequestMethod.GET})
    public EventEnvelope publishGame(@RequestParam String gameId, @RequestParam String title) {
        EventEnvelope event = EventEnvelope.of(
                "GamePublished",
                Map.of("gameId", gameId, "title", title)
        );
        producer.publish(gameId, event);
        return event;
    }

}
