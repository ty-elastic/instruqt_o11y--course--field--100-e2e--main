package com.example.recorder;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpResponse.BodyHandlers;

/**
 * Service layer is where all the business logic lies
 */
@Service
@Slf4j
public class TradeNotifier {

    private ObjectMapper mapper = new ObjectMapper();
    private String notifierEndpoint;

    public TradeNotifier() {
        try {
            notifierEndpoint = System.getenv("NOTIFIER_ENDPOINT");
        } catch (Exception e) 
        {
            notifierEndpoint = "http://notifier:5000/notify";
        }
    }

    public void notify(Trade trade) {
        try {
            String body = mapper.writeValueAsString(trade);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(new URI(notifierEndpoint))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body))
                    .build();

            HttpResponse<String> response = HttpClient.newBuilder()
                    .build()
                    .send(request, BodyHandlers.ofString());
        }
        catch (Exception e) {
            log.warn("unable to notify", e);
        }
    }
}
