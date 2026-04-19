package main

import (
	"context"
	"math/rand"
	"sync"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	sdkresource "go.opentelemetry.io/otel/sdk/resource"
)

// nodeMemState holds kubeletstats-style memory fields for a node.
type nodeMemState struct {
	capacity   int64
	usage      int64
	available  int64
	rss        int64
	workingSet int64
}

// nodeFSState holds kubeletstats filesystem fields for a node.
type nodeFSState struct {
	capacity  int64
	usage     int64
	available int64
}

// nodeNetState holds cumulative kubeletstats network counters for a node.
type nodeNetState struct {
	rxBytes  int64
	txBytes  int64
	rxErrors int64
	txErrors int64
}

// podKubeletState tracks resource usage for one pod as seen by kubeletstats.
type podKubeletState struct {
	name       string
	namespace  string
	cpuUsage   float64 // nanocores
	memUsage   int64
	memRSS     int64
	memWS      int64
	fsUsage    int64
	netRxBytes int64
	netTxBytes int64
	containers []containerKubeletState
}

// containerKubeletState tracks resource usage for one container via kubeletstats.
type containerKubeletState struct {
	name     string
	cpuUsage float64 // nanocores
	memUsage int64
	memRSS   int64
	memWS    int64
}

// NodeSimulator owns two OTel MeterProviders — one for the k8s_cluster receiver
// (node conditions, pod phases, container resource requests) and one for the
// kubeletstats receiver (live CPU/memory/filesystem/network usage).
//
// Call clusterTick (via ClusterSimulator.tick) to advance pod/container state,
// and kubeletTick before each kubeletstats collect+export.
type NodeSimulator struct {
	name        string
	clusterName string
	index       int
	rng         *rand.Rand
	mu          sync.RWMutex

	// Shared pod definitions (written by clusterTick, read by cluster callback)
	pods []PodState

	// k8s_cluster receiver
	clusterReader   *sdkmetric.ManualReader
	clusterProvider *sdkmetric.MeterProvider

	// kubeletstats receiver
	kubeletReader   *sdkmetric.ManualReader
	kubeletProvider *sdkmetric.MeterProvider

	// Node resource state
	cpuCapacity float64 // nanocores (total allocatable)
	cpuUsage    float64 // nanocores (current usage)
	nodeMem     nodeMemState
	nodeFS      nodeFSState
	nodeNet     nodeNetState

	// Per-pod kubelet state
	podKubelet []podKubeletState
}

func NewNodeSimulator(name, clusterName string, index int, pods []PodState) *NodeSimulator {
	n := &NodeSimulator{
		name:        name,
		clusterName: clusterName,
		index:       index,
		rng:         rand.New(rand.NewSource(int64(index)*0xDEADBEEF + 99)),
		pods:        pods,
	}
	n.initKubeletState()
	n.setupClusterMetrics()
	n.setupKubeletMetrics()
	return n
}

func (n *NodeSimulator) initKubeletState() {
	// CPU: 4, 8, 16, or 32 cores
	coreCount := int64(4) << uint(n.rng.Intn(4))
	n.cpuCapacity = float64(coreCount) * 1e9 // nanocores
	n.cpuUsage = n.cpuCapacity * (0.15 + n.rng.Float64()*0.55)

	// Memory: 8–128 GiB
	memGB := int64(8) << uint(n.rng.Intn(5))
	cap := memGB << 30
	usage := int64(float64(cap) * (0.3 + n.rng.Float64()*0.4))
	n.nodeMem = nodeMemState{
		capacity:   cap,
		usage:      usage,
		available:  cap - usage,
		rss:        int64(float64(usage) * 0.8),
		workingSet: int64(float64(usage) * 0.9),
	}

	// Filesystem: 50–800 GiB
	fsGB := int64(50) << uint(n.rng.Intn(5))
	fsCap := fsGB << 30
	fsUsage := int64(float64(fsCap) * (0.2 + n.rng.Float64()*0.5))
	n.nodeFS = nodeFSState{
		capacity:  fsCap,
		usage:     fsUsage,
		available: fsCap - fsUsage,
	}

	n.nodeNet = nodeNetState{
		rxBytes: n.rng.Int63n(100 << 30),
		txBytes: n.rng.Int63n(100 << 30),
	}

	// Pod kubelet states
	n.podKubelet = make([]podKubeletState, len(n.pods))
	numPods := len(n.pods)
	for i, pod := range n.pods {
		podCPU := n.cpuUsage / float64(numPods) * (0.5 + n.rng.Float64())
		podMem := int64(float64(n.nodeMem.usage) / float64(numPods) * (0.5 + n.rng.Float64()))

		containers := make([]containerKubeletState, len(pod.containers))
		for k, c := range pod.containers {
			cCPU := podCPU / float64(len(pod.containers)) * (0.7 + n.rng.Float64()*0.6)
			cMem := podMem / int64(len(pod.containers))
			containers[k] = containerKubeletState{
				name:     c.name,
				cpuUsage: cCPU,
				memUsage: cMem,
				memRSS:   int64(float64(cMem) * 0.8),
				memWS:    int64(float64(cMem) * 0.9),
			}
		}
		n.podKubelet[i] = podKubeletState{
			name:       pod.name,
			namespace:  pod.namespace,
			cpuUsage:   podCPU,
			memUsage:   podMem,
			memRSS:     int64(float64(podMem) * 0.8),
			memWS:      int64(float64(podMem) * 0.9),
			fsUsage:    n.rng.Int63n(1 << 30),
			netRxBytes: n.rng.Int63n(10 << 30),
			netTxBytes: n.rng.Int63n(5 << 30),
			containers: containers,
		}
	}
}

// ---- k8s_cluster metrics ----

func (n *NodeSimulator) setupClusterMetrics() {
	res, _ := sdkresource.New(context.Background(),
		sdkresource.WithAttributes(
			attribute.String("k8s.node.name", n.name),
			attribute.String("k8s.cluster.name", n.clusterName),
			attribute.String("data_stream.dataset", "k8sclusterreceiver"),
		),
	)
	n.clusterReader = sdkmetric.NewManualReader()
	n.clusterProvider = sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(n.clusterReader),
	)
	n.registerClusterMetrics()
}

func (n *NodeSimulator) registerClusterMetrics() {
	m := n.clusterProvider.Meter("otelcol/k8sclusterreceiver")

	nodeReady, _ := m.Int64ObservableGauge("k8s.node.condition_ready",
		metric.WithDescription("Whether the node is in Ready condition (1=true, 0=false)."),
		metric.WithUnit("1"),
	)
	nodeMemPressure, _ := m.Int64ObservableGauge("k8s.node.condition_memory_pressure",
		metric.WithDescription("Whether the node is under memory pressure (1=true, 0=false)."),
		metric.WithUnit("1"),
	)
	podPhase, _ := m.Int64ObservableGauge("k8s.pod.phase",
		metric.WithDescription("Current pod phase (1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown)."),
		metric.WithUnit("1"),
	)
	containerReady, _ := m.Int64ObservableGauge("k8s.container.ready",
		metric.WithDescription("Whether the container is ready (1=true, 0=false)."),
		metric.WithUnit("1"),
	)
	containerRestarts, _ := m.Int64ObservableGauge("k8s.container.restarts",
		metric.WithDescription("Number of container restarts."),
		metric.WithUnit("{restart}"),
	)
	containerCPUReq, _ := m.Float64ObservableGauge("k8s.container.cpu_request",
		metric.WithDescription("CPU requested by the container, in millicores."),
		metric.WithUnit("{millicore}"),
	)
	containerCPULim, _ := m.Float64ObservableGauge("k8s.container.cpu_limit",
		metric.WithDescription("CPU limit of the container, in millicores."),
		metric.WithUnit("{millicore}"),
	)
	containerMemReq, _ := m.Int64ObservableGauge("k8s.container.memory_request",
		metric.WithDescription("Memory requested by the container, in bytes."),
		metric.WithUnit("By"),
	)
	containerMemLim, _ := m.Int64ObservableGauge("k8s.container.memory_limit",
		metric.WithDescription("Memory limit of the container, in bytes."),
		metric.WithUnit("By"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		n.mu.RLock()
		defer n.mu.RUnlock()

		memPressure := int64(0)
		if float64(n.nodeMem.usage) > float64(n.nodeMem.capacity)*0.85 {
			memPressure = 1
		}
		o.ObserveInt64(nodeReady, 1)
		o.ObserveInt64(nodeMemPressure, memPressure)

		for _, pod := range n.pods {
			podAttrs := []attribute.KeyValue{
				attribute.String("k8s.pod.name", pod.name),
				attribute.String("k8s.namespace.name", pod.namespace),
			}
			o.ObserveInt64(podPhase, pod.phase, metric.WithAttributes(podAttrs...))

			for _, c := range pod.containers {
				cAttrs := []attribute.KeyValue{
					attribute.String("k8s.container.name", c.name),
					attribute.String("k8s.pod.name", pod.name),
					attribute.String("k8s.namespace.name", pod.namespace),
				}
				o.ObserveInt64(containerReady, c.ready, metric.WithAttributes(cAttrs...))
				o.ObserveInt64(containerRestarts, c.restarts, metric.WithAttributes(cAttrs...))
				o.ObserveFloat64(containerCPUReq, c.cpuRequest, metric.WithAttributes(cAttrs...))
				o.ObserveFloat64(containerCPULim, c.cpuLimit, metric.WithAttributes(cAttrs...))
				o.ObserveInt64(containerMemReq, c.memoryRequest, metric.WithAttributes(cAttrs...))
				o.ObserveInt64(containerMemLim, c.memoryLimit, metric.WithAttributes(cAttrs...))
			}
		}
		return nil
	}, nodeReady, nodeMemPressure, podPhase,
		containerReady, containerRestarts, containerCPUReq, containerCPULim,
		containerMemReq, containerMemLim)
}

// clusterTick advances pod phases and container ready/restart state.
// Called by ClusterSimulator.tick under the cluster's write lock; uses the
// shared cluster RNG (which is safe because tick is single-threaded).
func (n *NodeSimulator) clusterTick(rng *rand.Rand) {
	n.mu.Lock()
	defer n.mu.Unlock()

	for i := range n.pods {
		if rng.Float64() < 0.02 {
			n.pods[i].phase = 4 // briefly Failed
		} else {
			n.pods[i].phase = 2 // Running
		}
		for k := range n.pods[i].containers {
			if rng.Float64() < 0.005 {
				n.pods[i].containers[k].restarts++
			}
			if rng.Float64() < 0.02 {
				n.pods[i].containers[k].ready = 0
			} else {
				n.pods[i].containers[k].ready = 1
			}
		}
	}
}

// ---- kubeletstats metrics ----

func (n *NodeSimulator) setupKubeletMetrics() {
	res, _ := sdkresource.New(context.Background(),
		sdkresource.WithAttributes(
			attribute.String("k8s.node.name", n.name),
			attribute.String("k8s.cluster.name", n.clusterName),
			attribute.String("data_stream.dataset", "kubeletstatsreceiver"),
		),
	)
	n.kubeletReader = sdkmetric.NewManualReader()
	n.kubeletProvider = sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(n.kubeletReader),
	)
	n.registerKubeletMetrics()
}

func (n *NodeSimulator) registerKubeletMetrics() {
	m := n.kubeletProvider.Meter("otelcol/kubeletstatsreceiver")

	// Node-level instruments
	nodeCPUUtil, _ := m.Float64ObservableGauge("k8s.node.cpu.utilization",
		metric.WithDescription("Node CPU utilization as a ratio of usage to limit (0.0–1.0)."),
		metric.WithUnit("1"),
	)
	nodeCPUUsage, _ := m.Float64ObservableGauge("k8s.node.cpu.usage",
		metric.WithDescription("Node CPU usage in nanocores."),
		metric.WithUnit("n{core}"),
	)
	nodeMemAvail, _ := m.Int64ObservableGauge("k8s.node.memory.available",
		metric.WithDescription("Node available memory in bytes."),
		metric.WithUnit("By"),
	)
	nodeMemUsage, _ := m.Int64ObservableGauge("k8s.node.memory.usage",
		metric.WithDescription("Node memory usage in bytes."),
		metric.WithUnit("By"),
	)
	nodeMemRSS, _ := m.Int64ObservableGauge("k8s.node.memory.rss",
		metric.WithDescription("Node memory RSS in bytes."),
		metric.WithUnit("By"),
	)
	nodeMemWS, _ := m.Int64ObservableGauge("k8s.node.memory.working_set",
		metric.WithDescription("Node memory working set in bytes."),
		metric.WithUnit("By"),
	)
	nodeFSAvail, _ := m.Int64ObservableGauge("k8s.node.filesystem.available",
		metric.WithDescription("Node filesystem available bytes."),
		metric.WithUnit("By"),
	)
	nodeFSCap, _ := m.Int64ObservableGauge("k8s.node.filesystem.capacity",
		metric.WithDescription("Node filesystem capacity bytes."),
		metric.WithUnit("By"),
	)
	nodeFSUsage, _ := m.Int64ObservableGauge("k8s.node.filesystem.usage",
		metric.WithDescription("Node filesystem usage bytes."),
		metric.WithUnit("By"),
	)
	nodeNetIO, _ := m.Int64ObservableCounter("k8s.node.network.io",
		metric.WithDescription("Node network I/O in bytes."),
		metric.WithUnit("By"),
	)
	nodeNetErr, _ := m.Int64ObservableCounter("k8s.node.network.errors",
		metric.WithDescription("Node network errors."),
		metric.WithUnit("{error}"),
	)

	// Pod-level instruments
	podCPUUtil, _ := m.Float64ObservableGauge("k8s.pod.cpu.utilization",
		metric.WithDescription("Pod CPU utilization as a ratio of usage to limit (0.0–1.0)."),
		metric.WithUnit("1"),
	)
	podCPUUsage, _ := m.Float64ObservableGauge("k8s.pod.cpu.usage",
		metric.WithDescription("Pod CPU usage in nanocores."),
		metric.WithUnit("n{core}"),
	)
	podMemUsage, _ := m.Int64ObservableGauge("k8s.pod.memory.usage",
		metric.WithDescription("Pod memory usage in bytes."),
		metric.WithUnit("By"),
	)
	podMemRSS, _ := m.Int64ObservableGauge("k8s.pod.memory.rss",
		metric.WithDescription("Pod memory RSS in bytes."),
		metric.WithUnit("By"),
	)
	podMemWS, _ := m.Int64ObservableGauge("k8s.pod.memory.working_set",
		metric.WithDescription("Pod memory working set in bytes."),
		metric.WithUnit("By"),
	)
	podFSUsage, _ := m.Int64ObservableGauge("k8s.pod.filesystem.usage",
		metric.WithDescription("Pod filesystem usage bytes."),
		metric.WithUnit("By"),
	)
	podNetIO, _ := m.Int64ObservableCounter("k8s.pod.network.io",
		metric.WithDescription("Pod network I/O in bytes."),
		metric.WithUnit("By"),
	)
	podNetErr, _ := m.Int64ObservableCounter("k8s.pod.network.errors",
		metric.WithDescription("Pod network errors."),
		metric.WithUnit("{error}"),
	)

	// Container-level instruments
	ctrCPUUtil, _ := m.Float64ObservableGauge("k8s.container.cpu.utilization",
		metric.WithDescription("Container CPU utilization as a ratio of usage to limit (0.0–1.0)."),
		metric.WithUnit("1"),
	)
	ctrCPUUsage, _ := m.Float64ObservableGauge("k8s.container.cpu.usage",
		metric.WithDescription("Container CPU usage in nanocores."),
		metric.WithUnit("n{core}"),
	)
	ctrMemUsage, _ := m.Int64ObservableGauge("k8s.container.memory.usage",
		metric.WithDescription("Container memory usage in bytes."),
		metric.WithUnit("By"),
	)
	ctrMemRSS, _ := m.Int64ObservableGauge("k8s.container.memory.rss",
		metric.WithDescription("Container memory RSS in bytes."),
		metric.WithUnit("By"),
	)
	ctrMemWS, _ := m.Int64ObservableGauge("k8s.container.memory.working_set",
		metric.WithDescription("Container memory working set in bytes."),
		metric.WithUnit("By"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		n.mu.RLock()
		defer n.mu.RUnlock()

		// Node
		nodeUtil := n.cpuUsage / n.cpuCapacity
		o.ObserveFloat64(nodeCPUUtil, nodeUtil)
		o.ObserveFloat64(nodeCPUUsage, n.cpuUsage)
		o.ObserveInt64(nodeMemAvail, n.nodeMem.available)
		o.ObserveInt64(nodeMemUsage, n.nodeMem.usage)
		o.ObserveInt64(nodeMemRSS, n.nodeMem.rss)
		o.ObserveInt64(nodeMemWS, n.nodeMem.workingSet)
		o.ObserveInt64(nodeFSAvail, n.nodeFS.available)
		o.ObserveInt64(nodeFSCap, n.nodeFS.capacity)
		o.ObserveInt64(nodeFSUsage, n.nodeFS.usage)
		o.ObserveInt64(nodeNetIO, n.nodeNet.rxBytes,
			metric.WithAttributes(attribute.String("direction", "receive")))
		o.ObserveInt64(nodeNetIO, n.nodeNet.txBytes,
			metric.WithAttributes(attribute.String("direction", "transmit")))
		o.ObserveInt64(nodeNetErr, n.nodeNet.rxErrors,
			metric.WithAttributes(attribute.String("direction", "receive")))
		o.ObserveInt64(nodeNetErr, n.nodeNet.txErrors,
			metric.WithAttributes(attribute.String("direction", "transmit")))

		// Pods and containers
		for _, pod := range n.podKubelet {
			podAttrs := []attribute.KeyValue{
				attribute.String("k8s.pod.name", pod.name),
				attribute.String("k8s.namespace.name", pod.namespace),
			}
			podUtil := pod.cpuUsage / n.cpuCapacity
			o.ObserveFloat64(podCPUUtil, podUtil, metric.WithAttributes(podAttrs...))
			o.ObserveFloat64(podCPUUsage, pod.cpuUsage, metric.WithAttributes(podAttrs...))
			o.ObserveInt64(podMemUsage, pod.memUsage, metric.WithAttributes(podAttrs...))
			o.ObserveInt64(podMemRSS, pod.memRSS, metric.WithAttributes(podAttrs...))
			o.ObserveInt64(podMemWS, pod.memWS, metric.WithAttributes(podAttrs...))
			o.ObserveInt64(podFSUsage, pod.fsUsage, metric.WithAttributes(podAttrs...))
			o.ObserveInt64(podNetIO, pod.netRxBytes,
				metric.WithAttributes(append(podAttrs, attribute.String("direction", "receive"))...))
			o.ObserveInt64(podNetIO, pod.netTxBytes,
				metric.WithAttributes(append(podAttrs, attribute.String("direction", "transmit"))...))
			o.ObserveInt64(podNetErr, 0,
				metric.WithAttributes(append(podAttrs, attribute.String("direction", "receive"))...))
			o.ObserveInt64(podNetErr, 0,
				metric.WithAttributes(append(podAttrs, attribute.String("direction", "transmit"))...))

			for _, c := range pod.containers {
				cAttrs := []attribute.KeyValue{
					attribute.String("k8s.container.name", c.name),
					attribute.String("k8s.pod.name", pod.name),
					attribute.String("k8s.namespace.name", pod.namespace),
				}
				cUtil := c.cpuUsage / n.cpuCapacity
				o.ObserveFloat64(ctrCPUUtil, cUtil, metric.WithAttributes(cAttrs...))
				o.ObserveFloat64(ctrCPUUsage, c.cpuUsage, metric.WithAttributes(cAttrs...))
				o.ObserveInt64(ctrMemUsage, c.memUsage, metric.WithAttributes(cAttrs...))
				o.ObserveInt64(ctrMemRSS, c.memRSS, metric.WithAttributes(cAttrs...))
				o.ObserveInt64(ctrMemWS, c.memWS, metric.WithAttributes(cAttrs...))
			}
		}
		return nil
	},
		nodeCPUUtil, nodeCPUUsage,
		nodeMemAvail, nodeMemUsage, nodeMemRSS, nodeMemWS,
		nodeFSAvail, nodeFSCap, nodeFSUsage,
		nodeNetIO, nodeNetErr,
		podCPUUtil, podCPUUsage,
		podMemUsage, podMemRSS, podMemWS, podFSUsage,
		podNetIO, podNetErr,
		ctrCPUUtil, ctrCPUUsage,
		ctrMemUsage, ctrMemRSS, ctrMemWS,
	)
}

// kubeletTick advances the node's kubeletstats simulation by one interval.
func (n *NodeSimulator) kubeletTick(interval time.Duration) {
	n.mu.Lock()
	defer n.mu.Unlock()

	secs := interval.Seconds()
	rng := n.rng

	// CPU drift
	n.cpuUsage = clampF(n.cpuUsage+(rng.Float64()-0.5)*0.1*n.cpuCapacity,
		n.cpuCapacity*0.05, n.cpuCapacity*0.95)

	// Memory drift
	memDrift := int64((rng.Float64() - 0.5) * 0.04 * float64(n.nodeMem.capacity))
	n.nodeMem.usage = clamp64(n.nodeMem.usage+memDrift,
		n.nodeMem.capacity/10, n.nodeMem.capacity*9/10)
	n.nodeMem.available = n.nodeMem.capacity - n.nodeMem.usage
	n.nodeMem.rss = int64(float64(n.nodeMem.usage) * 0.8)
	n.nodeMem.workingSet = int64(float64(n.nodeMem.usage) * 0.9)

	// Filesystem: slow growth
	n.nodeFS.usage = clamp64(n.nodeFS.usage+rng.Int63n(10<<20)*int64(secs)/60,
		0, n.nodeFS.capacity*95/100)
	n.nodeFS.available = n.nodeFS.capacity - n.nodeFS.usage

	// Network: cumulative counters
	n.nodeNet.rxBytes += rng.Int63n(50_000_000) * int64(secs)
	n.nodeNet.txBytes += rng.Int63n(20_000_000) * int64(secs)
	if rng.Float64() < 0.01 {
		n.nodeNet.rxErrors++
	}

	// Pod drift
	for i := range n.podKubelet {
		pod := &n.podKubelet[i]
		pod.cpuUsage = clampF(
			pod.cpuUsage*(1.0+(rng.Float64()-0.5)*0.2),
			1e6, n.cpuCapacity*0.5,
		)
		memD := int64((rng.Float64() - 0.5) * 0.1 * float64(pod.memUsage))
		pod.memUsage = clamp64(pod.memUsage+memD, 1<<20, n.nodeMem.capacity/2)
		pod.memRSS = int64(float64(pod.memUsage) * 0.8)
		pod.memWS = int64(float64(pod.memUsage) * 0.9)
		pod.netRxBytes += rng.Int63n(5_000_000) * int64(secs)
		pod.netTxBytes += rng.Int63n(2_000_000) * int64(secs)

		for k := range pod.containers {
			c := &pod.containers[k]
			c.cpuUsage = clampF(
				c.cpuUsage*(1.0+(rng.Float64()-0.5)*0.2),
				1e5, n.cpuCapacity*0.3,
			)
			cMemD := int64((rng.Float64() - 0.5) * 0.1 * float64(c.memUsage))
			c.memUsage = clamp64(c.memUsage+cMemD, 1<<20, n.nodeMem.capacity/4)
			c.memRSS = int64(float64(c.memUsage) * 0.8)
			c.memWS = int64(float64(c.memUsage) * 0.9)
		}
	}
}

func clamp64(v, lo, hi int64) int64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func clampF(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
