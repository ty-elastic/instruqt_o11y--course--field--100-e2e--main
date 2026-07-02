package main

import (
	"fmt"
	"net/url"
	"sync/atomic"
)

// Backend represents a single upstream server.
type Backend struct {
	URL     *url.URL
	healthy atomic.Bool
}

// BackendPool manages a set of backends with round-robin selection over healthy members.
type BackendPool struct {
	backends []*Backend
	counter  atomic.Uint64
}

// newBackendPool parses the given URL strings and creates a pool with all backends
// initially marked healthy (optimistic start).
func newBackendPool(urls []string) (*BackendPool, error) {
	pool := &BackendPool{}
	for _, u := range urls {
		parsed, err := url.Parse(u)
		if err != nil {
			return nil, fmt.Errorf("parsing backend URL %q: %w", u, err)
		}
		b := &Backend{URL: parsed}
		b.healthy.Store(true)
		pool.backends = append(pool.backends, b)
	}
	return pool, nil
}

// Next returns the next healthy backend via round-robin. Returns nil if none are healthy.
func (p *BackendPool) Next() *Backend {
	healthy := p.Healthy()
	if len(healthy) == 0 {
		return nil
	}
	idx := p.counter.Add(1) - 1
	return healthy[idx%uint64(len(healthy))]
}

// Healthy returns a snapshot of the currently healthy backends.
func (p *BackendPool) Healthy() []*Backend {
	var out []*Backend
	for _, b := range p.backends {
		if b.healthy.Load() {
			out = append(out, b)
		}
	}
	return out
}

// HealthyCount returns the number of healthy backends.
func (p *BackendPool) HealthyCount() int {
	n := 0
	for _, b := range p.backends {
		if b.healthy.Load() {
			n++
		}
	}
	return n
}

// UnhealthyCount returns the number of unhealthy backends.
func (p *BackendPool) UnhealthyCount() int {
	return len(p.backends) - p.HealthyCount()
}

// All returns all backends (healthy and unhealthy).
func (p *BackendPool) All() []*Backend {
	return p.backends
}
