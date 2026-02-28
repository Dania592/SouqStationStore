package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.GamePurchasedEvent;
import com.souqstation.schemas.events.DLCPurchasedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformPurchaseEventProducer {

    private final KafkaTemplate<String, Object> purchaseTemplate;
    private final String purchaseTopic;

    public PlatformPurchaseEventProducer(
            KafkaTemplate<String, Object> purchaseTemplate,
            @Value("${souq.kafka.topics.platform.purchase:souq.platform.purchase.events}") String purchaseTopic) {
        this.purchaseTemplate = purchaseTemplate;
        this.purchaseTopic = purchaseTopic;
    }

    public void publishPurchase(String key, GamePurchasedEvent event) {
        purchaseTemplate.send(purchaseTopic, key, event);
    }

    public void publishDlcPurchase(String key, DLCPurchasedEvent event) {
        purchaseTemplate.send(purchaseTopic, key, event);
    }
}
