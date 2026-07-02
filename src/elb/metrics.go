package main

import (
	"sync"
	"sync/atomic"
)

// WindowSnapshot holds the aggregated metric values for one 5-second flush window.
type WindowSnapshot struct {
	// Counter metrics (reset to 0 after each Snapshot).
	RequestCount   int64
	ProcessedBytes int64
	ELB3XX         int64
	ELB4XX         int64
	ELB5XX         int64
	ELB503         int64
	Tgt2XX         int64
	Tgt3XX         int64
	Tgt4XX         int64

	// TargetResponseTime accumulators (reset after each Snapshot).
	TRTSum   float64
	TRTCount int64
	TRTMax   float64

	// Per-backend request counts for RequestCountPerTarget fan-out.
	PerBackend map[string]int64

	// Gauge metrics (read without reset).
	InFlight int64

	// Health state (read from the backend pool at snapshot time).
	HealthyHosts   int
	UnhealthyHosts int
}

// lbAgg accumulates per-request metrics for one load balancer.
// The hot path uses lock-free atomics for counters; a small mutex
// guards the float accumulator and per-backend map.
type lbAgg struct {
	requestCount   atomic.Int64
	processedBytes atomic.Int64
	elb3xx         atomic.Int64
	elb4xx         atomic.Int64
	elb5xx         atomic.Int64
	elb503         atomic.Int64
	tgt2xx         atomic.Int64
	tgt3xx         atomic.Int64
	tgt4xx         atomic.Int64
	inFlight       atomic.Int64 // gauge: incremented on entry, decremented on exit

	mu         sync.Mutex
	trtSum     float64
	trtCount   int64
	trtMax     float64
	perBackend map[string]int64
}

func newLBAgg() *lbAgg {
	return &lbAgg{perBackend: make(map[string]int64)}
}

// InFlightInc increments the in-flight request gauge.
func (a *lbAgg) InFlightInc() { a.inFlight.Add(1) }

// InFlightDec decrements the in-flight request gauge.
func (a *lbAgg) InFlightDec() { a.inFlight.Add(-1) }

// RecordRequest records the outcome of a completed (or failed) proxied request.
//
//   - backendURL: empty string if no backend was selected (503 case).
//   - statusCode: final HTTP status code returned to the client.
//   - reqBytes / respBytes: bytes transferred.
//   - targetSec: backend response latency in seconds; negative if not applicable.
//   - isProxyError: true when the ELB itself generated the error (connection failure, 503, etc.).
func (a *lbAgg) RecordRequest(backendURL string, statusCode int, reqBytes, respBytes int64, targetSec float64, isProxyError bool) {
	a.requestCount.Add(1)
	a.processedBytes.Add(reqBytes + respBytes)

	switch {
	case statusCode == 503 && backendURL == "":
		// No healthy backend — ELB-generated 503.
		a.elb503.Add(1)
	case isProxyError && statusCode >= 500:
		a.elb5xx.Add(1)
	case isProxyError && statusCode >= 400:
		a.elb4xx.Add(1)
	case isProxyError && statusCode >= 300:
		a.elb3xx.Add(1)
	case statusCode >= 500:
		// Backend 5xx — surfaced as ELB 5xx (502/504 from the proxy perspective).
		a.elb5xx.Add(1)
	case statusCode >= 400:
		a.tgt4xx.Add(1)
	case statusCode >= 300:
		a.tgt3xx.Add(1)
	case statusCode >= 200:
		a.tgt2xx.Add(1)
	}

	if targetSec >= 0 && backendURL != "" {
		a.mu.Lock()
		a.trtSum += targetSec
		a.trtCount++
		if targetSec > a.trtMax {
			a.trtMax = targetSec
		}
		a.perBackend[backendURL]++
		a.mu.Unlock()
	}
}

// Snapshot reads-and-zeros all counter-type metrics and returns them along with
// a copy of the per-backend map and a read of the current gauge and health state.
// The inFlight gauge is NOT reset (it is maintained continuously).
func (a *lbAgg) Snapshot(pool *BackendPool) WindowSnapshot {
	a.mu.Lock()
	trtSum := a.trtSum
	trtCount := a.trtCount
	trtMax := a.trtMax
	perBackend := a.perBackend
	a.trtSum = 0
	a.trtCount = 0
	a.trtMax = 0
	a.perBackend = make(map[string]int64)
	a.mu.Unlock()

	return WindowSnapshot{
		RequestCount:   a.requestCount.Swap(0),
		ProcessedBytes: a.processedBytes.Swap(0),
		ELB3XX:         a.elb3xx.Swap(0),
		ELB4XX:         a.elb4xx.Swap(0),
		ELB5XX:         a.elb5xx.Swap(0),
		ELB503:         a.elb503.Swap(0),
		Tgt2XX:         a.tgt2xx.Swap(0),
		Tgt3XX:         a.tgt3xx.Swap(0),
		Tgt4XX:         a.tgt4xx.Swap(0),
		TRTSum:         trtSum,
		TRTCount:       trtCount,
		TRTMax:         trtMax,
		PerBackend:     perBackend,
		InFlight:       a.inFlight.Load(),
		HealthyHosts:   pool.HealthyCount(),
		UnhealthyHosts: pool.UnhealthyCount(),
	}
}
