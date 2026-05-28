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

@RestController
@RequiredArgsConstructor
@Validated
@Slf4j
public class Controller {

	@Autowired(required = false)
    private Producer producer;

	@GetMapping("/health")
    public ResponseEntity<String> health() {
			return ResponseEntity.ok().body("KERNEL OK");
    }

	@PostMapping("/notify")
    public ResponseEntity<String> trade(
		@RequestParam(value = "trade_id") String tradeId,
		@RequestParam(value = "database") String database,
		@RequestParam(value = "flags") String flags
	) throws ExecutionException, InterruptedException {

		log.info("notify rx");

		if (producer != null) {
			log.info("prod not null");
			producer.notify(String.format("trade_id=%s&database=%s&flags=%s", tradeId, database, flags));
		}

		return ResponseEntity.ok().body("NOTIFIED");
    }
}
