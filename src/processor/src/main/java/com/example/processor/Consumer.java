package com.example.processor;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.errors.WakeupException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.apache.kafka.common.serialization.IntegerDeserializer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpResponse.BodyHandlers;
import java.time.Duration;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Properties;
import java.util.UUID;

import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Service;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.web.util.UriComponentsBuilder;
import java.util.LinkedHashMap;
import java.util.Map;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpResponse.BodyHandlers;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;

public class Consumer {
    private static final Logger log = LoggerFactory.getLogger(Consumer.class);

    private final String topicName;

    private KafkaConsumer<Integer, String> consumer;

    ObjectMapper mapper = new ObjectMapper();

    public KafkaConsumer<Integer, String> createKafkaConsumer(String bootstrapServer, String groupName) {
        Properties props = new Properties();
        // bootstrap server config is required for producer to connect to brokers
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServer);
        // client id is not required, but it's good to track the source of requests beyond just ip/port
        // by allowing a logical application name to be included in server-side request logging
        //props.put(ConsumerConfig.CLIENT_ID_CONFIG, "client-" + UUID.randomUUID());

        props.setProperty(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, IntegerDeserializer.class.getName());
        props.setProperty(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.setProperty(ConsumerConfig.GROUP_ID_CONFIG, groupName);
        props.setProperty(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");

        return new KafkaConsumer<>(props);
    }

    public Consumer(String bootstrapServer, String topicName, String groupName) {
        this.topicName = topicName;
        //groupName = groupName + "-" + UUID.randomUUID().toString();
        consumer = createKafkaConsumer(bootstrapServer, groupName);
    }

    public void wakeup() {
        consumer.wakeup(); 
    }

    public HttpResponse<String> httpNotify (String notifierEndpoint, String body) {
        try {
            Map<String, Object> params = mapper.readValue(body, new TypeReference<Map<String, Object>>(){});
            UriComponentsBuilder builder = UriComponentsBuilder.fromUriString(notifierEndpoint);
            // Add map entries to the builder
            params.forEach(builder::queryParam);
            // Build and encode the URI string
            String uriString = builder.build().encode().toUriString();

            //log.info("notifying " + uriString);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(new URI(uriString))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(""))
                    .build();

            HttpResponse<String> response = HttpClient.newBuilder()
                    .build()
                    .send(request, BodyHandlers.ofString());

            log.info("relayed to " + notifierEndpoint);

            return response;
        }
        catch (Exception e) {
            log.warn("unable to notify: " + e.toString());
            return null;
        }
    }

    public void run(Producer producer, String outEndpoint) {

        try {
            // subscribe consumer to our topic(s)
            consumer.subscribe(Arrays.asList(this.topicName));

            // poll for new data
            while (true) {
                ConsumerRecords<Integer, String> records =
                        consumer.poll(Duration.ofMillis(100));

                try {
                    for (ConsumerRecord<Integer, String> record : records) {
                        //log.info("Key: " + record.key() + ", Value: " + record.value());
                        //log.info("Partition: " + record.partition() + ", Offset:" + record.offset());
                        
                        if (producer != null)
                            producer.notify(record.value());

                        if (outEndpoint != null)
                            httpNotify(outEndpoint, record.value());
                    }
                    consumer.commitSync();
                }
                catch (Exception e) {
                    log.warn("Failed to process record" + e.toString());
                }
            }

        } catch (WakeupException e) {
            log.info("Wake up exception!");
            // we ignore this as this is an expected exception when closing a consumer
        } catch (Exception e) {
            log.error("Unexpected exception", e);
        } finally {
            consumer.close(); // this will also commit the offsets if need be.
            log.info("The consumer is now gracefully closed.");
        }

    }
}