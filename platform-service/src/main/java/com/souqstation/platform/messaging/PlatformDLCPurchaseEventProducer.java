package com.souqstation.platform.messaging;

import com.souqstation.schemas.events.DLCPurchasedEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformDLCPurchaseEventProducer {

    private final KafkaTemplate<String, DLCPurchasedEvent> dlcPurchaseTemplate;

    private final String purchaseTopic;

    public PlatformDLCPurchaseEventProducer(
            KafkaTemplate<String, DLCPurchasedEvent> dlcPurchaseTemplate,
            @Value("${souq.kafka.topics.platform.purchase}") String purchaseTopic
    ) {
        this.dlcPurchaseTemplate = dlcPurchaseTemplate;
        this.purchaseTopic = purchaseTopic;
    }

    public void publishDLCPurchase(String key, DLCPurchasedEvent event) {
        dlcPurchaseTemplate.send(purchaseTopic, key, event);
        System.out.println("[PRODUCER] DLCPurchased published: " + event.getPurchaseId());
    }
}
