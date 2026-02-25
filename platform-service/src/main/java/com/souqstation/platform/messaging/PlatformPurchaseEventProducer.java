package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.GamePurchasedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformPurchaseEventProducer {

    private final KafkaTemplate<String, GamePurchasedEvent> purchaseTemplate;
    private final String purchaseTopic;

    public PlatformPurchaseEventProducer(
            KafkaTemplate<String, GamePurchasedEvent> purchaseTemplate,
            @Value("${souq.kafka.topics.platform.purchase:souq.platform.purchase.events}") String purchaseTopic
    ) {
        this.purchaseTemplate = purchaseTemplate;
        this.purchaseTopic = purchaseTopic;
    }

    public void publishPurchase(String key, GamePurchasedEvent event) {
        purchaseTemplate.send(purchaseTopic, key, event);
    }
}
