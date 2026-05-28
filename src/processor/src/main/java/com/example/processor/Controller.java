package com.example.processor;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import org.springframework.beans.factory.annotation.Autowired;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import java.util.concurrent.ExecutionException;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequiredArgsConstructor
@Validated
@Slf4j
public class Controller {

	@Autowired(required = false)
    private Producer producer;

	ObjectMapper mapper = new ObjectMapper();

	@GetMapping("/health")
    public ResponseEntity<String> health() {
			return ResponseEntity.ok().body("KERNEL OK");
    }

	@PostMapping("/**")
    public ResponseEntity<String> trade(
		@RequestParam Map<String, String> allParams
	) throws ExecutionException, InterruptedException, com.fasterxml.jackson.core.JsonProcessingException {

		log.info("notify rx");

		if (producer != null) {
			String jsonResult = mapper.writeValueAsString(allParams);
			log.info("notify rx with body: " + jsonResult);
			producer.notify(jsonResult);
		}

		return ResponseEntity.ok().body("NOTIFIED");
    }
}
