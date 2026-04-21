package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"runtime"
	"strconv"
	"sync"
	"syscall"
	"time"

	"crypto/tls"

	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/metric/metricdata"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
)

type Config struct {
	OTLPEndpoint    string
	OTLPAuthHeader  string
	OTLPInsecure    bool
	HostCount       int
	CollectInterval time.Duration
	Workers         int
	HostPrefix      string
}

func parseConfig() *Config {
	cfg := &Config{}
	flag.StringVar(&cfg.OTLPEndpoint, "otlp-endpoint", envOr("OTLP_ENDPOINT", "localhost:4317"), "OTLP gRPC endpoint (host:port)")
	flag.StringVar(&cfg.OTLPAuthHeader, "otlp-auth-header", envOr("OTLP_AUTH_HEADER", ""), "value for the Authorization header (e.g. \"Bearer <token>\" or \"ApiKey <key>\")")
	flag.BoolVar(&cfg.OTLPInsecure, "otlp-insecure", envOr("OTLP_INSECURE", "") == "true", "disable TLS (plaintext gRPC)")
	flag.IntVar(&cfg.HostCount, "host-count", envIntOr("HOST_COUNT", 10), "number of simulated hosts")
	flag.DurationVar(&cfg.CollectInterval, "interval", envDurationOr("COLLECT_INTERVAL", 60*time.Second), "metric collection interval")
	flag.IntVar(&cfg.Workers, "workers", runtime.NumCPU()*4, "parallel goroutines for collection/export")
	flag.StringVar(&cfg.HostPrefix, "host-prefix", envOr("HOST_PREFIX", "sim-host"), "simulated hostname prefix")
	flag.Parse()
	return cfg
}

func main() {
	cfg := parseConfig()

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	var transportCreds grpc.DialOption
	if cfg.OTLPInsecure {
		transportCreds = grpc.WithTransportCredentials(insecure.NewCredentials())
	} else {
		transportCreds = grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{}))
	}
	conn, err := grpc.NewClient(cfg.OTLPEndpoint, transportCreds)
	if err != nil {
		log.Fatalf("grpc dial: %v", err)
	}
	defer conn.Close()

	exporterOpts := []otlpmetricgrpc.Option{otlpmetricgrpc.WithGRPCConn(conn)}
	if cfg.OTLPAuthHeader != "" {
		exporterOpts = append(exporterOpts, otlpmetricgrpc.WithHeaders(map[string]string{
			"Authorization": cfg.OTLPAuthHeader,
		}))
	}
	exporter, err := otlpmetricgrpc.New(ctx, exporterOpts...)
	if err != nil {
		log.Fatalf("create exporter: %v", err)
	}
	defer func() {
		if err := exporter.Shutdown(context.Background()); err != nil {
			log.Printf("exporter shutdown: %v", err)
		}
	}()

	log.Printf("initializing %d hosts...", cfg.HostCount)
	hosts := make([]*HostSimulator, cfg.HostCount)
	for i := 0; i < cfg.HostCount; i++ {
		hosts[i] = NewHostSimulator(fmt.Sprintf("%s-%04d", cfg.HostPrefix, i+1), i)
	}
	log.Printf("ready: hosts=%d interval=%s endpoint=%s workers=%d",
		cfg.HostCount, cfg.CollectInterval, cfg.OTLPEndpoint, cfg.Workers)

	sem := make(chan struct{}, cfg.Workers)
	ticker := time.NewTicker(cfg.CollectInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			shutdownAll(hosts)
			return
		case t := <-ticker.C:
			collectAll(ctx, t, hosts, exporter, sem, cfg.CollectInterval)
		}
	}
}

func collectAll(ctx context.Context, t time.Time, hosts []*HostSimulator, exporter sdkmetric.Exporter, sem chan struct{}, interval time.Duration) {
	var wg sync.WaitGroup
	var exported, errs int64
	var mu sync.Mutex

	for _, h := range hosts {
		wg.Add(1)
		sem <- struct{}{}
		go func(host *HostSimulator) {
			defer wg.Done()
			defer func() { <-sem }()

			host.tick(interval)

			var rm metricdata.ResourceMetrics
			if err := host.reader.Collect(ctx, &rm); err != nil {
				mu.Lock()
				errs++
				mu.Unlock()
				log.Printf("collect %s: %v", host.hostname, err)
				return
			}
			if err := exporter.Export(ctx, &rm); err != nil {
				mu.Lock()
				errs++
				mu.Unlock()
				log.Printf("export %s: %v", host.hostname, err)
				return
			}
			mu.Lock()
			exported++
			mu.Unlock()
		}(h)
	}
	wg.Wait()
	log.Printf("%s exported=%d errors=%d", t.Format(time.RFC3339), exported, errs)
}

func shutdownAll(hosts []*HostSimulator) {
	ctx := context.Background()
	for _, h := range hosts {
		if err := h.provider.Shutdown(ctx); err != nil {
			log.Printf("shutdown %s: %v", h.hostname, err)
		}
	}
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func envIntOr(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func envDurationOr(key string, def time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}
