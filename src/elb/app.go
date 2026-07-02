package main

import (
	"context"
	"fmt"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

// App wires together all load balancers, the ES client, health checkers, and flush goroutines.
type App struct {
	cfg      *Config
	lbs      []*LoadBalancer
	checkers []*HealthChecker
	es       *ESClient
	hostName string
}

// NewApp builds the application from a validated Config.
func NewApp(cfg *Config) (*App, error) {
	hostName := GetHostName()
	es := NewESClient(cfg.Elasticsearch.URL, cfg.Elasticsearch.APIKey, cfg.Elasticsearch.InsecureSkipVerify)

	var lbs []*LoadBalancer
	var checkers []*HealthChecker

	for _, lbCfg := range cfg.LoadBalancers {
		lb, err := NewLoadBalancer(lbCfg, cfg)
		if err != nil {
			return nil, fmt.Errorf("load balancer %q: %w", lbCfg.Name, err)
		}

		hcCfg := cfg.HealthCheck // start with global default
		if lbCfg.HealthCheck != nil {
			hcCfg = *lbCfg.HealthCheck
		}
		hc := NewHealthChecker(lb.pool, hcCfg)

		lbs = append(lbs, lb)
		checkers = append(checkers, hc)
	}

	return &App{
		cfg:      cfg,
		lbs:      lbs,
		checkers: checkers,
		es:       es,
		hostName: hostName,
	}, nil
}

// Run starts all subsystems and blocks until ctx is cancelled (e.g. SIGINT/SIGTERM).
// Shutdown sequence:
//  1. Stop accepting new connections on all LB servers.
//  2. Stop health checkers.
//  3. Perform a final flush of buffered logs and metrics.
//  4. Close idle ES connections.
func (a *App) Run(ctx context.Context) {
	// 1. Start health checkers.
	hcCtx, hcCancel := context.WithCancel(context.Background())
	for _, hc := range a.checkers {
		go hc.Run(hcCtx)
	}

	// 2. Start flush goroutines.
	flushCtx, flushCancel := context.WithCancel(context.Background())
	var flushWG sync.WaitGroup
	flushWG.Add(2)
	go RunLogFlusher(flushCtx, &flushWG, a.lbs, a.es, a.cfg.Elasticsearch.LogsDatastream)
	go RunMetricFlusher(flushCtx, &flushWG, a.lbs, a.es, a.cfg.Elasticsearch.MetricsDatastream, a.cfg, a.hostName)

	// 3. Start load balancer servers (each blocks; run in goroutines).
	for _, lb := range a.lbs {
		go lb.Start()
	}

	log.Info("elb load balancer started")

	// 4. Block until the OS signal cancels the context.
	<-ctx.Done()
	log.Info("shutdown signal received")

	// 5. Gracefully stop LB servers (drain in-flight requests).
	shutCtx, shutCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutCancel()
	for _, lb := range a.lbs {
		if err := lb.Shutdown(shutCtx); err != nil {
			log.WithField("lb", lb.cfg.Name).WithError(err).Warn("shutdown error")
		}
	}

	// 6. Stop health checkers.
	hcCancel()

	// 7. Final flush: cancel the flush context and wait for both goroutines to complete.
	flushCancel()
	flushWG.Wait()

	// 8. Release idle ES connections.
	a.es.CloseIdleConnections()

	log.Info("shutdown complete")
}
