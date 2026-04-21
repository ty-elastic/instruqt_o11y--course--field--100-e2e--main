package main

import (
	"context"
	"crypto/tls"
	"flag"
	"log"
	"os"
	"os/signal"
	"runtime"
	"strconv"
	"sync"
	"syscall"
	"time"

	otlploggrpc "go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	sdklog "go.opentelemetry.io/otel/sdk/log"
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
	ClusterName     string
	NodeCount       int
	NamespaceCount  int
	PodsPerNode     int
	ClusterInterval time.Duration
	KubeletInterval time.Duration
	Workers         int
}

func parseConfig() *Config {
	cfg := &Config{}
	flag.StringVar(&cfg.OTLPEndpoint, "otlp-endpoint", envOr("OTLP_ENDPOINT", "localhost:4317"), "OTLP gRPC endpoint (host:port)")
	flag.StringVar(&cfg.OTLPAuthHeader, "otlp-auth-header", envOr("OTLP_AUTH_HEADER", ""), "value for the Authorization header (e.g. \"Bearer <token>\" or \"ApiKey <key>\")")
	flag.BoolVar(&cfg.OTLPInsecure, "otlp-insecure", envOr("OTLP_INSECURE", "") == "true", "disable TLS (plaintext gRPC)")
	flag.StringVar(&cfg.ClusterName, "cluster-name", envOr("CLUSTER_NAME", "sim-cluster"), "simulated cluster name")
	flag.IntVar(&cfg.NodeCount, "node-count", envIntOr("NODE_COUNT", 3), "number of simulated nodes")
	flag.IntVar(&cfg.NamespaceCount, "namespace-count", envIntOr("NAMESPACE_COUNT", 5), "number of simulated namespaces (excluding builtins)")
	flag.IntVar(&cfg.PodsPerNode, "pods-per-node", envIntOr("PODS_PER_NODE", 10), "pods per node")
	flag.DurationVar(&cfg.ClusterInterval, "cluster-interval", envDurationOr("CLUSTER_INTERVAL", 30*time.Second), "k8s_cluster + k8s_events + k8sobjects collection interval")
	flag.DurationVar(&cfg.KubeletInterval, "kubelet-interval", envDurationOr("KUBELET_INTERVAL", 20*time.Second), "kubeletstats collection interval")
	flag.IntVar(&cfg.Workers, "workers", runtime.NumCPU()*4, "parallel goroutines for collection/export")
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

	// Metric exporter
	metricOpts := []otlpmetricgrpc.Option{otlpmetricgrpc.WithGRPCConn(conn)}
	if cfg.OTLPAuthHeader != "" {
		metricOpts = append(metricOpts, otlpmetricgrpc.WithHeaders(map[string]string{
			"Authorization": cfg.OTLPAuthHeader,
		}))
	}
	metricExporter, err := otlpmetricgrpc.New(ctx, metricOpts...)
	if err != nil {
		log.Fatalf("create metric exporter: %v", err)
	}
	defer func() {
		if err := metricExporter.Shutdown(context.Background()); err != nil {
			log.Printf("metric exporter shutdown: %v", err)
		}
	}()

	// Log exporter
	logOpts := []otlploggrpc.Option{otlploggrpc.WithGRPCConn(conn)}
	if cfg.OTLPAuthHeader != "" {
		logOpts = append(logOpts, otlploggrpc.WithHeaders(map[string]string{
			"Authorization": cfg.OTLPAuthHeader,
		}))
	}
	logExporter, err := otlploggrpc.New(ctx, logOpts...)
	if err != nil {
		log.Fatalf("create log exporter: %v", err)
	}
	logProvider := sdklog.NewLoggerProvider(
		sdklog.WithProcessor(sdklog.NewSimpleProcessor(logExporter)),
	)
	defer func() {
		if err := logProvider.Shutdown(context.Background()); err != nil {
			log.Printf("log provider shutdown: %v", err)
		}
	}()

	log.Printf("initializing cluster %q: nodes=%d namespaces=%d pods-per-node=%d",
		cfg.ClusterName, cfg.NodeCount, cfg.NamespaceCount, cfg.PodsPerNode)

	cluster := NewClusterSimulator(cfg.ClusterName, cfg.NodeCount, cfg.NamespaceCount, cfg.PodsPerNode, logProvider)

	log.Printf("ready: cluster=%s nodes=%d cluster-interval=%s kubelet-interval=%s endpoint=%s workers=%d",
		cfg.ClusterName, cfg.NodeCount, cfg.ClusterInterval, cfg.KubeletInterval, cfg.OTLPEndpoint, cfg.Workers)

	sem := make(chan struct{}, cfg.Workers)
	clusterTicker := time.NewTicker(cfg.ClusterInterval)
	kubeletTicker := time.NewTicker(cfg.KubeletInterval)
	defer clusterTicker.Stop()
	defer kubeletTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			shutdownAll(cluster)
			return
		case t := <-clusterTicker.C:
			collectCluster(ctx, t, cluster, metricExporter, sem, cfg.ClusterInterval)
		case t := <-kubeletTicker.C:
			collectKubelet(ctx, t, cluster.nodes, metricExporter, sem, cfg.KubeletInterval)
		}
	}
}

func collectCluster(ctx context.Context, t time.Time, cluster *ClusterSimulator, exporter sdkmetric.Exporter, sem chan struct{}, interval time.Duration) {
	cluster.tick(interval)
	cluster.emitLogs(ctx)

	var exported, errs int64
	var mu sync.Mutex
	var wg sync.WaitGroup

	// Per-node k8s_cluster metrics
	for _, node := range cluster.nodes {
		wg.Add(1)
		sem <- struct{}{}
		go func(n *NodeSimulator) {
			defer wg.Done()
			defer func() { <-sem }()
			var rm metricdata.ResourceMetrics
			if err := n.clusterReader.Collect(ctx, &rm); err != nil {
				mu.Lock(); errs++; mu.Unlock()
				log.Printf("cluster collect %s: %v", n.name, err)
				return
			}
			if err := exporter.Export(ctx, &rm); err != nil {
				mu.Lock(); errs++; mu.Unlock()
				log.Printf("cluster export %s: %v", n.name, err)
				return
			}
			mu.Lock(); exported++; mu.Unlock()
		}(node)
	}

	// Cluster-wide metrics (namespaces, deployments)
	wg.Add(1)
	sem <- struct{}{}
	go func() {
		defer wg.Done()
		defer func() { <-sem }()
		var rm metricdata.ResourceMetrics
		if err := cluster.clusterWideReader.Collect(ctx, &rm); err != nil {
			mu.Lock(); errs++; mu.Unlock()
			log.Printf("cluster-wide collect: %v", err)
			return
		}
		if err := exporter.Export(ctx, &rm); err != nil {
			mu.Lock(); errs++; mu.Unlock()
			log.Printf("cluster-wide export: %v", err)
			return
		}
		mu.Lock(); exported++; mu.Unlock()
	}()

	wg.Wait()
	log.Printf("%s [cluster] exported=%d errors=%d", t.UTC().Format(time.RFC3339), exported, errs)
}

func collectKubelet(ctx context.Context, t time.Time, nodes []*NodeSimulator, exporter sdkmetric.Exporter, sem chan struct{}, interval time.Duration) {
	var exported, errs int64
	var mu sync.Mutex
	var wg sync.WaitGroup

	for _, node := range nodes {
		wg.Add(1)
		sem <- struct{}{}
		go func(n *NodeSimulator) {
			defer wg.Done()
			defer func() { <-sem }()
			n.kubeletTick(interval)
			var rm metricdata.ResourceMetrics
			if err := n.kubeletReader.Collect(ctx, &rm); err != nil {
				mu.Lock(); errs++; mu.Unlock()
				log.Printf("kubelet collect %s: %v", n.name, err)
				return
			}
			if err := exporter.Export(ctx, &rm); err != nil {
				mu.Lock(); errs++; mu.Unlock()
				log.Printf("kubelet export %s: %v", n.name, err)
				return
			}
			mu.Lock(); exported++; mu.Unlock()
		}(node)
	}
	wg.Wait()
	log.Printf("%s [kubelet] exported=%d errors=%d", t.UTC().Format(time.RFC3339), exported, errs)
}

func shutdownAll(cluster *ClusterSimulator) {
	ctx := context.Background()
	if err := cluster.clusterWideProvider.Shutdown(ctx); err != nil {
		log.Printf("cluster-wide provider shutdown: %v", err)
	}
	for _, n := range cluster.nodes {
		if err := n.clusterProvider.Shutdown(ctx); err != nil {
			log.Printf("cluster provider shutdown %s: %v", n.name, err)
		}
		if err := n.kubeletProvider.Shutdown(ctx); err != nil {
			log.Printf("kubelet provider shutdown %s: %v", n.name, err)
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
