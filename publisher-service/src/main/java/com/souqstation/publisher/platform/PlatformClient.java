package com.souqstation.publisher.platform;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

@Component
public class PlatformClient {

    private final RestTemplate restTemplate;
    private final String platformBaseUrl;

    public PlatformClient(RestTemplate restTemplate,
                          @Value("${souq.platform.url:http://localhost:8081}") String platformBaseUrl) {
        this.restTemplate = restTemplate;
        this.platformBaseUrl = platformBaseUrl;
    }

    public boolean redactorExists(String userId) {
        String url = platformBaseUrl + "/platform/redactors/exists?userId={userId}";
        Map<?, ?> res = restTemplate.getForObject(url, Map.class, userId);
        Object exists = (res != null) ? res.get("exists") : null;
        return exists instanceof Boolean b && b;
    }
}