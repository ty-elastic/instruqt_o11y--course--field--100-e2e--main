package com.example.recorder;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

/**
 * Service layer is where all the business logic lies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class TradeService {
	private final TradeNotifier tradeNotifier;
	private final TradeRecorder tradeRecorder;

    @Async
    public CompletableFuture<Trade> processTrade (Trade trade){
        tradeNotifier.notify(trade);

        Trade resp = tradeRecorder.recordTrade(trade);
        return CompletableFuture.completedFuture(resp);
    }
}
