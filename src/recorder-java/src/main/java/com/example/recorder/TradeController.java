package com.example.recorder;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import java.util.concurrent.ExecutionException;

import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;


@RestController
@RequiredArgsConstructor
@Validated
@Slf4j
public class TradeController {

    private final TradeService tradeService;
	private final Argon2PasswordEncoder arg2SpringSecurity = new Argon2PasswordEncoder(16, 32, 1, 10000, 10);

	@GetMapping("/health")
    public ResponseEntity<String> health() {
			return ResponseEntity.ok().body("KERNEL OK");
    }

	@PostMapping("/record")
    public ResponseEntity<Trade> trade(@RequestParam(value = "customer_id") String customerId,
		@RequestParam(value = "trade_id") String tradeId,
		@RequestParam(value = "flags", defaultValue="") String flags,
		@RequestParam(value = "symbol") String symbol,
		@RequestParam(value = "shares") int shares,
		@RequestParam(value = "share_price") float sharePrice,
		@RequestParam(value = "action") String action) throws ExecutionException, InterruptedException {
			Trade trade = new Trade(tradeId, customerId, symbol, shares, sharePrice, action);
			
			if (flags.contains("ENCRYPT")) {
				log.info("encrypting...");
				for (int i=0; i < 25; i++) {
					String hash = arg2SpringSecurity.encode(customerId);
				}
			}
			if (flags.contains("GC")) {
				log.info("thrash GC");
				Utilities.thrashGarbageCollector();
			}

			CompletableFuture<Trade> resp = tradeService.processTrade(trade);

			return ResponseEntity.ok().body(resp.get());
    }
}
