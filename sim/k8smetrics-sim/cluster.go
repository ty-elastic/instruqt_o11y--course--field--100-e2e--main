package main

import (
	"context"
	"fmt"
	"math/rand"
	"sync"
	"time"

	"go.opentelemetry.io/otel/attribute"
	otellog "go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/metric"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	sdkresource "go.opentelemetry.io/otel/sdk/resource"
)

type NamespaceState struct {
	name  string
	phase int64 // 1=active, 0=terminating
}

type DeploymentState struct {
	name      string
	namespace string
	desired   int64
	available int64
}

// PodState is shared between ClusterSimulator (for k8s_cluster metrics)
// and NodeSimulator (for kubeletstats). Each field mirrors a real k8s pod attribute.
type PodState struct {
	name       string
	namespace  string
	phase      int64 // 1=Pending 2=Running 3=Succeeded 4=Failed 5=Unknown
	containers []ContainerState
}

type ContainerState struct {
	name          string
	cpuRequest    float64 // millicores
	cpuLimit      float64 // millicores
	memoryRequest int64   // bytes
	memoryLimit   int64   // bytes
	ready         int64   // 0 or 1
	restarts      int64
}

// ClusterSimulator holds the full simulated cluster state. It owns the
// k8s_cluster-receiver metrics (via per-node providers + a cluster-wide provider)
// and emits k8s_events / k8sobjects log records on each tick.
type ClusterSimulator struct {
	clusterName string
	rng         *rand.Rand
	mu          sync.RWMutex

	nodes      []*NodeSimulator
	namespaces []NamespaceState
	deployments []DeploymentState

	// cluster-wide provider: namespace phase + deployment metrics
	clusterWideReader   *sdkmetric.ManualReader
	clusterWideProvider *sdkmetric.MeterProvider

	eventsLogger  otellog.Logger
	objectsLogger otellog.Logger
}

var depNamePool = []string{
	"frontend", "backend", "api", "worker", "cache",
	"proxy", "scheduler", "gateway", "auth", "metrics",
}

func NewClusterSimulator(clusterName string, nodeCount, namespaceCount, podsPerNode int, logProvider *sdklog.LoggerProvider) *ClusterSimulator {
	c := &ClusterSimulator{
		clusterName:   clusterName,
		rng:           rand.New(rand.NewSource(0xCAFEBABEDEAD)),
		eventsLogger:  logProvider.Logger("otelcol/k8seventsreceiver"),
		objectsLogger: logProvider.Logger("otelcol/k8sobjectsreceiver"),
	}

	// Namespaces: builtins + simulated
	c.namespaces = []NamespaceState{
		{name: "default", phase: 1},
		{name: "kube-system", phase: 1},
	}
	for i := 0; i < namespaceCount; i++ {
		c.namespaces = append(c.namespaces, NamespaceState{
			name:  fmt.Sprintf("sim-ns-%03d", i+1),
			phase: 1,
		})
	}

	// Deployments: 1–3 per non-system namespace
	for _, ns := range c.namespaces {
		if ns.name == "kube-system" {
			continue
		}
		for j := 0; j < 1+c.rng.Intn(3); j++ {
			desired := int64(1 + c.rng.Intn(4))
			c.deployments = append(c.deployments, DeploymentState{
				name:      depNamePool[c.rng.Intn(len(depNamePool))],
				namespace: ns.name,
				desired:   desired,
				available: desired,
			})
		}
	}

	// Non-system namespaces for pod distribution
	var podNS []string
	for _, ns := range c.namespaces {
		if ns.name != "kube-system" {
			podNS = append(podNS, ns.name)
		}
	}

	// Nodes with their pods
	c.nodes = make([]*NodeSimulator, nodeCount)
	for i := 0; i < nodeCount; i++ {
		nodeName := fmt.Sprintf("sim-node-%03d", i+1)
		nodeRNG := rand.New(rand.NewSource(int64(i)*0xDEADBEEF + 42))

		pods := make([]PodState, podsPerNode)
		for j := 0; j < podsPerNode; j++ {
			ns := podNS[nodeRNG.Intn(len(podNS))]
			numContainers := 1 + nodeRNG.Intn(3)
			containers := make([]ContainerState, numContainers)
			for k := range containers {
				containers[k] = ContainerState{
					name:          fmt.Sprintf("container-%d", k),
					cpuRequest:    float64(50 + nodeRNG.Intn(450)),
					cpuLimit:      float64(500 + nodeRNG.Intn(1500)),
					memoryRequest: int64(64+nodeRNG.Intn(448)) << 20,
					memoryLimit:   int64(256+nodeRNG.Intn(768)) << 20,
					ready:         1,
					restarts:      nodeRNG.Int63n(5),
				}
			}
			pods[j] = PodState{
				name:       fmt.Sprintf("sim-pod-%s-%04d", nodeName[4:], j+1), // strip "sim-"
				namespace:  ns,
				phase:      2, // Running
				containers: containers,
			}
		}
		c.nodes[i] = NewNodeSimulator(nodeName, clusterName, i, pods)
	}

	c.setupClusterWideMetrics()
	return c
}

func (c *ClusterSimulator) setupClusterWideMetrics() {
	res, _ := sdkresource.New(context.Background(),
		sdkresource.WithAttributes(
			attribute.String("k8s.cluster.name", c.clusterName),
			attribute.String("data_stream.dataset", "k8sclusterreceiver"),
		),
	)
	c.clusterWideReader = sdkmetric.NewManualReader()
	c.clusterWideProvider = sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(c.clusterWideReader),
	)

	m := c.clusterWideProvider.Meter("otelcol/k8sclusterreceiver")

	nsPhase, _ := m.Int64ObservableGauge("k8s.namespace.phase",
		metric.WithDescription("Current phase of the namespace (1=active, 0=terminating)."),
		metric.WithUnit("1"),
	)
	depDesired, _ := m.Int64ObservableGauge("k8s.deployment.desired",
		metric.WithDescription("Number of desired pods in the deployment."),
		metric.WithUnit("{pod}"),
	)
	depAvailable, _ := m.Int64ObservableGauge("k8s.deployment.available",
		metric.WithDescription("Total number of available pods for the deployment."),
		metric.WithUnit("{pod}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		c.mu.RLock()
		defer c.mu.RUnlock()

		for _, ns := range c.namespaces {
			o.ObserveInt64(nsPhase, ns.phase,
				metric.WithAttributes(attribute.String("k8s.namespace.name", ns.name)))
		}
		for _, dep := range c.deployments {
			attrs := metric.WithAttributes(
				attribute.String("k8s.deployment.name", dep.name),
				attribute.String("k8s.namespace.name", dep.namespace),
			)
			o.ObserveInt64(depDesired, dep.desired, attrs)
			o.ObserveInt64(depAvailable, dep.available, attrs)
		}
		return nil
	}, nsPhase, depDesired, depAvailable)
}

// tick advances the cluster-wide simulation state.
func (c *ClusterSimulator) tick(_ time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	// Occasionally degrade a deployment temporarily
	for i := range c.deployments {
		if c.rng.Float64() < 0.05 {
			c.deployments[i].available = max64(0, c.deployments[i].desired-1)
		} else {
			c.deployments[i].available = c.deployments[i].desired
		}
	}

	// Tick each node's cluster-side pod/container state using the cluster RNG
	for _, node := range c.nodes {
		node.clusterTick(c.rng)
	}
}

// emitLogs emits k8s_events and k8sobjects log records for this tick.
func (c *ClusterSimulator) emitLogs(ctx context.Context) {
	now := time.Now()

	// k8s_events: 3–8 per tick
	for i := 0; i < 3+c.rng.Intn(6); i++ {
		c.emitEvent(ctx, now)
	}

	// k8sobjects watch events: 1–3 per tick
	for i := 0; i < 1+c.rng.Intn(3); i++ {
		c.emitObjectWatch(ctx, now)
	}
}

var normalReasons = []string{
	"ScalingReplicaSet", "Pulled", "Created", "Started", "SuccessfulCreate",
	"SuccessfulDelete", "Scheduled", "Pulling", "Killing", "NodeReady",
}
var warningReasons = []string{
	"BackOff", "FailedMount", "Unhealthy", "NodeNotReady",
	"OOMKilling", "FailedScheduling", "Evicted", "FailedPullImage",
}
var eventKinds = []string{"Deployment", "Pod", "ReplicaSet", "Node", "Service"}
var watchKinds = []struct{ kind, apiVersion string }{
	{"Pod", "v1"}, {"Deployment", "apps/v1"}, {"ReplicaSet", "apps/v1"},
	{"ConfigMap", "v1"}, {"Service", "v1"}, {"Node", "v1"},
}
var watchEventTypes = []string{"ADDED", "MODIFIED", "MODIFIED", "MODIFIED", "DELETED"}

func (c *ClusterSimulator) emitEvent(ctx context.Context, now time.Time) {
	isWarn := c.rng.Float64() < 0.2
	ns := c.namespaces[c.rng.Intn(len(c.namespaces))]
	kind := eventKinds[c.rng.Intn(len(eventKinds))]
	objName := fmt.Sprintf("sim-%s-%04d", kind, c.rng.Intn(100)+1)

	var reason, eventType string
	var sev otellog.Severity
	if isWarn {
		reason = warningReasons[c.rng.Intn(len(warningReasons))]
		eventType = "Warning"
		sev = otellog.SeverityWarn
	} else {
		reason = normalReasons[c.rng.Intn(len(normalReasons))]
		eventType = "Normal"
		sev = otellog.SeverityInfo
	}

	var r otellog.Record
	r.SetTimestamp(now)
	r.SetObservedTimestamp(now)
	r.SetBody(otellog.StringValue(fmt.Sprintf("%s: %s", eventType, reason)))
	r.SetSeverity(sev)
	r.SetSeverityText(eventType)
	r.AddAttributes(
		otellog.String("k8s.event.reason", reason),
		otellog.String("k8s.event.action", eventType),
		otellog.String("k8s.object.kind", kind),
		otellog.String("k8s.object.name", objName),
		otellog.String("k8s.namespace.name", ns.name),
		otellog.String("k8s.cluster.name", c.clusterName),
	)
	c.eventsLogger.Emit(ctx, r)
}

func (c *ClusterSimulator) emitObjectWatch(ctx context.Context, now time.Time) {
	wk := watchKinds[c.rng.Intn(len(watchKinds))]
	ns := c.namespaces[c.rng.Intn(len(c.namespaces))]
	name := fmt.Sprintf("sim-%s-%04d", wk.kind, c.rng.Intn(200)+1)
	watchType := watchEventTypes[c.rng.Intn(len(watchEventTypes))]

	body := fmt.Sprintf(
		`{"type":%q,"object":{"kind":%q,"apiVersion":%q,"metadata":{"name":%q,"namespace":%q,"resourceVersion":%q}}}`,
		watchType, wk.kind, wk.apiVersion, name, ns.name,
		fmt.Sprintf("%d", c.rng.Int63n(1_000_000)+1),
	)

	var r otellog.Record
	r.SetTimestamp(now)
	r.SetObservedTimestamp(now)
	r.SetBody(otellog.StringValue(body))
	r.SetSeverity(otellog.SeverityInfo)
	r.AddAttributes(
		otellog.String("k8s.object.kind", wk.kind),
		otellog.String("k8s.object.api_version", wk.apiVersion),
		otellog.String("event.name", watchType),
		otellog.String("k8s.namespace.name", ns.name),
		otellog.String("k8s.cluster.name", c.clusterName),
	)
	c.objectsLogger.Emit(ctx, r)
}

func max64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}
