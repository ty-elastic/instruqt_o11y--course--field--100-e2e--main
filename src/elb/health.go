package main

import (
	"context"
	"net/http"
	"time"

	log "github.com/sirupsen/logrus"
)

// HealthChecker periodically probes each backend and updates its healthy flag.
// It runs independently of the request-serving path.
type HealthChecker struct {
	pool   *BackendPool
	cfg    HealthConfig
	client *http.Client
}

// NewHealthChecker creates a checker for the given pool using cfg for probe settings.
func NewHealthChecker(pool *BackendPool, cfg HealthConfig) *HealthChecker {
	return &HealthChecker{
		pool: pool,
		cfg:  cfg,
		client: &http.Client{
			Timeout: cfg.Timeout,
			// Don't follow redirects — a redirect response still means the backend is alive.
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				return http.ErrUseLastResponse
			},
		},
	}
}

// Run performs an initial synchronous health check and then loops on the configured
// interval until ctx is cancelled.
func (hc *HealthChecker) Run(ctx context.Context) {
	hc.checkAll(ctx)
	ticker := time.NewTicker(hc.cfg.Interval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			hc.checkAll(ctx)
		case <-ctx.Done():
			return
		}
	}
}

func (hc *HealthChecker) checkAll(ctx context.Context) {
	for _, b := range hc.pool.All() {
		hc.checkOne(ctx, b)
	}
}

func (hc *HealthChecker) checkOne(ctx context.Context, b *Backend) {
	target := b.URL.Scheme + "://" + b.URL.Host + hc.cfg.Path

	reqCtx, cancel := context.WithTimeout(ctx, hc.cfg.Timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(reqCtx, http.MethodGet, target, nil)
	if err != nil {
		markUnhealthy(b)
		return
	}

	resp, err := hc.client.Do(req)
	if err != nil {
		markUnhealthy(b)
		if b.healthy.Load() {
			log.WithField("backend", b.URL.String()).WithError(err).Warn("backend health check failed")
		}
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 500 {
		if b.healthy.Load() {
			log.WithFields(log.Fields{
				"backend": b.URL.String(),
				"status":  resp.StatusCode,
			}).Warn("backend unhealthy")
		}
		b.healthy.Store(false)
	} else {
		if !b.healthy.Load() {
			log.WithField("backend", b.URL.String()).Info("backend recovered")
		}
		b.healthy.Store(true)
	}
}

func markUnhealthy(b *Backend) {
	b.healthy.Store(false)
}
