package main

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"sync"
	"time"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	sdkresource "go.opentelemetry.io/otel/sdk/resource"
)

// cpuStates matches the hostmetrics receiver's CPU state attribute values.
var cpuStates = []string{"user", "system", "idle", "interrupt", "nice", "softirq", "steal", "wait"}

// cpuUtil holds per-state utilization (sums to ~1.0) and cumulative time in seconds.
type cpuUtil struct {
	util [8]float64
	time [8]float64
}

type diskState struct {
	readBytes  int64
	writeBytes int64
	readOps    int64
	writeOps   int64
	ioTimeSecs float64
	opTimeSecs [2]float64 // [read, write]
	pending    int64
}

type netState struct {
	rxBytes   int64
	txBytes   int64
	rxPackets int64
	txPackets int64
	rxErrors  int64
	txErrors  int64
	rxDropped int64
	txDropped int64
}

// HostSimulator maintains the simulated state for a single host and owns its
// OTel MeterProvider + ManualReader. Call tick() each collection interval to
// advance the simulation, then Collect() + Export() via the ManualReader.
type HostSimulator struct {
	hostname string
	reader   *sdkmetric.ManualReader
	provider *sdkmetric.MeterProvider
	rng      *rand.Rand
	mu       sync.RWMutex

	// CPU
	cpuLogical  int
	cpuPhysical int
	cpus        []cpuUtil
	loadAvg1m   float64
	loadAvg5m   float64
	loadAvg15m  float64

	// Memory (bytes)
	memTotal             int64
	memUsed              int64
	memFree              int64
	memCached            int64
	memBuffered          int64
	memSlabReclaimable   int64
	memSlabUnreclaimable int64
	memLimit             int64

	// Disk
	diskDevices []string
	disks       map[string]*diskState

	// Filesystem (one root fs per host)
	fsDevice     string
	fsMountpoint string
	fsType       string
	fsMode       string
	fsTotal      int64
	fsUsed       int64
	fsFree       int64
	fsReserved   int64
	fsInodeTotal int64
	fsInodeUsed  int64
	fsInodeFree  int64

	// Network
	netDevices []string
	nets       map[string]*netState
	netConns   int64 // ESTABLISHED TCP connections

	// Processes
	procRunning  int64
	procSleeping int64
	procStopped  int64
	procZombie   int64
	procCreated  int64 // cumulative

	// Paging / swap
	swapTotal       int64
	swapUsed        int64
	swapFree        int64
	swapCached      int64
	pageFaultsMajor int64
	pageFaultsMinor int64
	pageInMajor     int64
	pageOutMajor    int64
	pageInMinor     int64
	pageOutMinor    int64
}

// NewHostSimulator creates a host with deterministic-but-varied initial state
// based on index, then registers all OTel metric callbacks.
func NewHostSimulator(hostname string, index int) *HostSimulator {
	h := &HostSimulator{
		hostname: hostname,
		rng:      rand.New(rand.NewSource(int64(index)*0xDEADBEEF + 42)),
	}
	h.initState()
	h.setupOTel(index)
	return h
}

// ---- state initialization ----

func (h *HostSimulator) initState() {
	// CPU: 1, 2, 4, 8, or 16 logical CPUs
	h.cpuLogical = 1 << uint(h.rng.Intn(5))
	h.cpuPhysical = h.cpuLogical / 2
	if h.cpuPhysical < 1 {
		h.cpuPhysical = 1
	}
	h.cpus = make([]cpuUtil, h.cpuLogical)
	for i := range h.cpus {
		h.initCPU(i)
	}
	h.recomputeLoadAvg()

	// Memory: 1–64 GB
	memGB := int64(1) << uint(h.rng.Intn(7))
	h.memTotal = memGB << 30
	h.memLimit = h.memTotal
	h.randomizeMemory()

	// Disks: 1–3 devices
	numDisks := 1 + h.rng.Intn(3)
	h.diskDevices = make([]string, numDisks)
	h.disks = make(map[string]*diskState, numDisks)
	for i := 0; i < numDisks; i++ {
		name := fmt.Sprintf("sd%c", rune('a'+i))
		h.diskDevices[i] = name
		h.disks[name] = &diskState{
			readBytes:  h.rng.Int63n(500 << 30),
			writeBytes: h.rng.Int63n(500 << 30),
			readOps:    h.rng.Int63n(10_000_000),
			writeOps:   h.rng.Int63n(5_000_000),
			ioTimeSecs: float64(h.rng.Int63n(3600)),
		}
	}

	// Filesystem on the first disk
	h.fsDevice = fmt.Sprintf("/dev/%s1", h.diskDevices[0])
	h.fsMountpoint = "/"
	h.fsType = "ext4"
	h.fsMode = "rw"
	fsGB := int64(20) << uint(h.rng.Intn(5)) // 20–320 GB
	h.fsTotal = fsGB << 30
	h.randomizeFilesystem()

	// Network interfaces: 1–2
	numNets := 1 + h.rng.Intn(2)
	h.netDevices = make([]string, numNets)
	h.nets = make(map[string]*netState, numNets)
	for i := 0; i < numNets; i++ {
		name := fmt.Sprintf("eth%d", i)
		h.netDevices[i] = name
		h.nets[name] = &netState{
			rxBytes:   h.rng.Int63n(100 << 30),
			txBytes:   h.rng.Int63n(100 << 30),
			rxPackets: h.rng.Int63n(500_000_000),
			txPackets: h.rng.Int63n(500_000_000),
		}
	}
	h.netConns = h.rng.Int63n(500) + 10

	// Processes
	h.procSleeping = h.rng.Int63n(200) + 20
	h.procRunning = h.rng.Int63n(int64(h.cpuLogical)) + 1
	h.procZombie = h.rng.Int63n(3)
	h.procCreated = h.rng.Int63n(100_000_000)

	// Swap: 2–16 GB
	swapGB := int64(2) << uint(h.rng.Intn(4))
	h.swapTotal = swapGB << 30
	h.swapUsed = h.rng.Int63n(h.swapTotal / 4)
	h.swapFree = h.swapTotal - h.swapUsed
	h.swapCached = h.rng.Int63n(h.swapUsed/2 + 1)
	h.pageFaultsMajor = h.rng.Int63n(100_000)
	h.pageFaultsMinor = h.rng.Int63n(1_000_000_000)
}

func (h *HostSimulator) initCPU(i int) {
	idle := 0.5 + h.rng.Float64()*0.4
	rem := 1.0 - idle
	user := rem * (0.4 + h.rng.Float64()*0.4)
	system := rem * (0.1 + h.rng.Float64()*0.3)
	nice := rem * h.rng.Float64() * 0.1
	softirq := rem * h.rng.Float64() * 0.05
	wait := rem * h.rng.Float64() * 0.05
	interrupt := math.Max(0, rem-user-system-nice-softirq-wait)
	h.cpus[i].util = [8]float64{user, system, idle, interrupt, nice, softirq, 0, wait}
}

func (h *HostSimulator) recomputeLoadAvg() {
	totalActive := 0.0
	for _, c := range h.cpus {
		totalActive += 1.0 - c.util[2] // 1 - idle
	}
	base := totalActive * (0.7 + h.rng.Float64()*0.6)
	noise := func() float64 { return 1.0 + (h.rng.Float64()-0.5)*0.1 }
	h.loadAvg1m = base * noise()
	h.loadAvg5m = base * 0.95 * noise()
	h.loadAvg15m = base * 0.9 * noise()
}

func (h *HostSimulator) randomizeMemory() {
	usedFrac := 0.3 + h.rng.Float64()*0.4
	h.memUsed = int64(float64(h.memTotal) * usedFrac)
	h.memCached = int64(float64(h.memTotal) * (0.1 + h.rng.Float64()*0.2))
	h.memBuffered = int64(float64(h.memTotal) * h.rng.Float64() * 0.05)
	h.memSlabReclaimable = int64(float64(h.memTotal) * h.rng.Float64() * 0.05)
	h.memSlabUnreclaimable = int64(float64(h.memTotal) * h.rng.Float64() * 0.02)
	h.memFree = h.memTotal - h.memUsed - h.memCached - h.memBuffered -
		h.memSlabReclaimable - h.memSlabUnreclaimable
	if h.memFree < 0 {
		h.memFree = 0
	}
}

func (h *HostSimulator) randomizeFilesystem() {
	h.fsReserved = int64(float64(h.fsTotal) * 0.05)
	h.fsUsed = int64(float64(h.fsTotal) * (0.2 + h.rng.Float64()*0.6))
	h.fsFree = h.fsTotal - h.fsUsed - h.fsReserved
	if h.fsFree < 0 {
		h.fsFree = 0
	}
	h.fsInodeTotal = h.fsTotal / 4096
	h.fsInodeUsed = int64(float64(h.fsInodeTotal) * (0.05 + h.rng.Float64()*0.3))
	h.fsInodeFree = h.fsInodeTotal - h.fsInodeUsed
}

// ---- OTel setup ----

func (h *HostSimulator) setupOTel(index int) {
	osTypes := []string{"linux", "linux", "linux", "windows"}
	archs := []string{"amd64", "amd64", "arm64"}

	resource, _ := sdkresource.New(context.Background(),
		sdkresource.WithAttributes(
			attribute.String("host.name", h.hostname),
			attribute.String("host.id", fmt.Sprintf("%016x", uint64(index)*0x9e3779b97f4a7c15+0xcafebabe)),
			attribute.String("host.arch", archs[index%len(archs)]),
			attribute.String("os.type", osTypes[index%len(osTypes)]),
			attribute.String("os.description", fmt.Sprintf("Linux 5.15.%d-generic #1 SMP", (index%50)+1)),
			attribute.String("data_stream.dataset", "hostmetricsreceiver"),
		),
	)

	h.reader = sdkmetric.NewManualReader()
	h.provider = sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(resource),
		sdkmetric.WithReader(h.reader),
	)

	h.registerCPUMetrics()
	h.registerMemoryMetrics()
	h.registerDiskMetrics()
	h.registerFilesystemMetrics()
	h.registerNetworkMetrics()
	h.registerProcessMetrics()
	h.registerPagingMetrics()
}

// ---- metric registration ----

func (h *HostSimulator) registerCPUMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/cpu")

	utilGauge, _ := m.Float64ObservableGauge("system.cpu.utilization",
		metric.WithDescription("Difference in system.cpu.time since the last measurement, divided by the elapsed time and number of logical CPUs."),
		metric.WithUnit("1"),
	)
	timeCounter, _ := m.Float64ObservableCounter("system.cpu.time",
		metric.WithDescription("Total seconds each logical CPU spent on each mode."),
		metric.WithUnit("s"),
	)
	load1m, _ := m.Float64ObservableGauge("system.cpu.load_average.1m",
		metric.WithDescription("Average CPU Load over 1 minute."),
		metric.WithUnit("{thread}"),
	)
	load5m, _ := m.Float64ObservableGauge("system.cpu.load_average.5m",
		metric.WithDescription("Average CPU Load over 5 minutes."),
		metric.WithUnit("{thread}"),
	)
	load15m, _ := m.Float64ObservableGauge("system.cpu.load_average.15m",
		metric.WithDescription("Average CPU Load over 15 minutes."),
		metric.WithUnit("{thread}"),
	)
	physicalCount, _ := m.Int64ObservableGauge("system.cpu.physical.count",
		metric.WithDescription("Number of physical processors on the host."),
		metric.WithUnit("{cpu}"),
	)
	logicalCount, _ := m.Int64ObservableGauge("system.cpu.logical.count",
		metric.WithDescription("Number of logical (virtual) processors on the host."),
		metric.WithUnit("{cpu}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		for i, cpu := range h.cpus {
			cpuAttr := attribute.String("cpu", fmt.Sprintf("cpu%d", i))
			for j, state := range cpuStates {
				attrs := metric.WithAttributes(cpuAttr, attribute.String("state", state))
				o.ObserveFloat64(utilGauge, cpu.util[j], attrs)
				o.ObserveFloat64(timeCounter, cpu.time[j], attrs)
			}
		}
		o.ObserveFloat64(load1m, h.loadAvg1m)
		o.ObserveFloat64(load5m, h.loadAvg5m)
		o.ObserveFloat64(load15m, h.loadAvg15m)
		o.ObserveInt64(physicalCount, int64(h.cpuPhysical))
		o.ObserveInt64(logicalCount, int64(h.cpuLogical))
		return nil
	}, utilGauge, timeCounter, load1m, load5m, load15m, physicalCount, logicalCount)
}

func (h *HostSimulator) registerMemoryMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/memory")

	usageCounter, _ := m.Int64ObservableUpDownCounter("system.memory.usage",
		metric.WithDescription("Bytes of memory in use."),
		metric.WithUnit("By"),
	)
	utilGauge, _ := m.Float64ObservableGauge("system.memory.utilization",
		metric.WithDescription("Percentage of memory bytes in use."),
		metric.WithUnit("1"),
	)
	limitCounter, _ := m.Int64ObservableUpDownCounter("system.memory.limit",
		metric.WithDescription("Total physical usable memory."),
		metric.WithUnit("By"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		total := float64(h.memTotal)
		memStates := []struct {
			name  string
			bytes int64
		}{
			{"used", h.memUsed},
			{"free", h.memFree},
			{"cached", h.memCached},
			{"buffered", h.memBuffered},
			{"slab_reclaimable", h.memSlabReclaimable},
			{"slab_unreclaimable", h.memSlabUnreclaimable},
		}
		for _, s := range memStates {
			attr := metric.WithAttributes(attribute.String("state", s.name))
			o.ObserveInt64(usageCounter, s.bytes, attr)
			o.ObserveFloat64(utilGauge, float64(s.bytes)/total, attr)
		}
		o.ObserveInt64(limitCounter, h.memLimit)
		return nil
	}, usageCounter, utilGauge, limitCounter)
}

func (h *HostSimulator) registerDiskMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/disk")

	ioCounter, _ := m.Int64ObservableCounter("system.disk.io",
		metric.WithDescription("The number of bytes transferred to/from the disk."),
		metric.WithUnit("By"),
	)
	opsCounter, _ := m.Int64ObservableCounter("system.disk.operations",
		metric.WithDescription("The number of disk I/O operations."),
		metric.WithUnit("{operation}"),
	)
	ioTimeCounter, _ := m.Float64ObservableCounter("system.disk.io_time",
		metric.WithDescription("Time disk spent activated, in seconds."),
		metric.WithUnit("s"),
	)
	opTimeCounter, _ := m.Float64ObservableCounter("system.disk.operation_time",
		metric.WithDescription("Sum of the time each operation took to complete, in seconds."),
		metric.WithUnit("s"),
	)
	pendingGauge, _ := m.Int64ObservableUpDownCounter("system.disk.pending_operations",
		metric.WithDescription("The queue size of pending I/O operations."),
		metric.WithUnit("{operation}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		for _, dev := range h.diskDevices {
			d := h.disks[dev]
			devAttr := attribute.String("device", dev)
			read := attribute.String("direction", "read")
			write := attribute.String("direction", "write")

			o.ObserveInt64(ioCounter, d.readBytes, metric.WithAttributes(devAttr, read))
			o.ObserveInt64(ioCounter, d.writeBytes, metric.WithAttributes(devAttr, write))
			o.ObserveInt64(opsCounter, d.readOps, metric.WithAttributes(devAttr, read))
			o.ObserveInt64(opsCounter, d.writeOps, metric.WithAttributes(devAttr, write))
			o.ObserveFloat64(ioTimeCounter, d.ioTimeSecs, metric.WithAttributes(devAttr))
			o.ObserveFloat64(opTimeCounter, d.opTimeSecs[0], metric.WithAttributes(devAttr, read))
			o.ObserveFloat64(opTimeCounter, d.opTimeSecs[1], metric.WithAttributes(devAttr, write))
			o.ObserveInt64(pendingGauge, d.pending, metric.WithAttributes(devAttr))
		}
		return nil
	}, ioCounter, opsCounter, ioTimeCounter, opTimeCounter, pendingGauge)
}

func (h *HostSimulator) registerFilesystemMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/filesystem")

	usageCounter, _ := m.Int64ObservableUpDownCounter("system.filesystem.usage",
		metric.WithDescription("Filesystem bytes used."),
		metric.WithUnit("By"),
	)
	utilGauge, _ := m.Float64ObservableGauge("system.filesystem.utilization",
		metric.WithDescription("Fraction of filesystem bytes used."),
		metric.WithUnit("1"),
	)
	inodeCounter, _ := m.Int64ObservableUpDownCounter("system.filesystem.inodes.usage",
		metric.WithDescription("FileSystem inodes used."),
		metric.WithUnit("{inodes}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		base := []attribute.KeyValue{
			attribute.String("device", h.fsDevice),
			attribute.String("mountpoint", h.fsMountpoint),
			attribute.String("type", h.fsType),
			attribute.String("mode", h.fsMode),
		}
		total := float64(h.fsTotal)

		fsStates := []struct {
			state string
			bytes int64
		}{
			{"used", h.fsUsed},
			{"free", h.fsFree},
			{"reserved", h.fsReserved},
		}
		for _, s := range fsStates {
			attrs := append(append([]attribute.KeyValue{}, base...), attribute.String("state", s.state))
			o.ObserveInt64(usageCounter, s.bytes, metric.WithAttributes(attrs...))
			o.ObserveFloat64(utilGauge, float64(s.bytes)/total, metric.WithAttributes(attrs...))
		}

		inodeStates := []struct {
			state string
			count int64
		}{
			{"used", h.fsInodeUsed},
			{"free", h.fsInodeFree},
		}
		for _, s := range inodeStates {
			attrs := append(append([]attribute.KeyValue{}, base...), attribute.String("state", s.state))
			o.ObserveInt64(inodeCounter, s.count, metric.WithAttributes(attrs...))
		}
		return nil
	}, usageCounter, utilGauge, inodeCounter)
}

func (h *HostSimulator) registerNetworkMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/network")

	ioCounter, _ := m.Int64ObservableCounter("system.network.io",
		metric.WithDescription("The number of bytes transmitted and received on each network interface."),
		metric.WithUnit("By"),
	)
	pktCounter, _ := m.Int64ObservableCounter("system.network.packets",
		metric.WithDescription("The number of packets transferred."),
		metric.WithUnit("{packets}"),
	)
	errCounter, _ := m.Int64ObservableCounter("system.network.errors",
		metric.WithDescription("The number of errors encountered."),
		metric.WithUnit("{errors}"),
	)
	dropCounter, _ := m.Int64ObservableCounter("system.network.dropped",
		metric.WithDescription("The number of packets dropped."),
		metric.WithUnit("{packets}"),
	)
	connGauge, _ := m.Int64ObservableUpDownCounter("system.network.connections",
		metric.WithDescription("The number of connections."),
		metric.WithUnit("{connections}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		for _, dev := range h.netDevices {
			n := h.nets[dev]
			devAttr := attribute.String("device", dev)
			pairs := []struct {
				dir  string
				io   int64
				pkts int64
				errs int64
				drop int64
			}{
				{"receive", n.rxBytes, n.rxPackets, n.rxErrors, n.rxDropped},
				{"transmit", n.txBytes, n.txPackets, n.txErrors, n.txDropped},
			}
			for _, p := range pairs {
				dirAttr := attribute.String("direction", p.dir)
				o.ObserveInt64(ioCounter, p.io, metric.WithAttributes(devAttr, dirAttr))
				o.ObserveInt64(pktCounter, p.pkts, metric.WithAttributes(devAttr, dirAttr))
				o.ObserveInt64(errCounter, p.errs, metric.WithAttributes(devAttr, dirAttr))
				o.ObserveInt64(dropCounter, p.drop, metric.WithAttributes(devAttr, dirAttr))
			}
		}
		o.ObserveInt64(connGauge, h.netConns,
			metric.WithAttributes(
				attribute.String("protocol", "tcp"),
				attribute.String("state", "ESTABLISHED"),
			))
		return nil
	}, ioCounter, pktCounter, errCounter, dropCounter, connGauge)
}

func (h *HostSimulator) registerProcessMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/process")

	countGauge, _ := m.Int64ObservableUpDownCounter("system.processes.count",
		metric.WithDescription("Total number of processes in each state."),
		metric.WithUnit("{processes}"),
	)
	createdCounter, _ := m.Int64ObservableCounter("system.processes.created",
		metric.WithDescription("Total number of created processes."),
		metric.WithUnit("{processes}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		procStates := []struct {
			status string
			count  int64
		}{
			{"running", h.procRunning},
			{"sleeping", h.procSleeping},
			{"stopped", h.procStopped},
			{"zombie", h.procZombie},
		}
		for _, s := range procStates {
			o.ObserveInt64(countGauge, s.count,
				metric.WithAttributes(attribute.String("status", s.status)))
		}
		o.ObserveInt64(createdCounter, h.procCreated)
		return nil
	}, countGauge, createdCounter)
}

func (h *HostSimulator) registerPagingMetrics() {
	m := h.provider.Meter("otelcol/hostmetricsreceiver/paging")

	usageCounter, _ := m.Int64ObservableUpDownCounter("system.paging.usage",
		metric.WithDescription("Unix swap / Windows page file usage."),
		metric.WithUnit("By"),
	)
	utilGauge, _ := m.Float64ObservableGauge("system.paging.utilization",
		metric.WithDescription("Fraction of swap bytes in use."),
		metric.WithUnit("1"),
	)
	faultsCounter, _ := m.Int64ObservableCounter("system.paging.faults",
		metric.WithDescription("The number of page faults."),
		metric.WithUnit("{faults}"),
	)
	opsCounter, _ := m.Int64ObservableCounter("system.paging.operations",
		metric.WithDescription("The number of paging operations."),
		metric.WithUnit("{operations}"),
	)

	_, _ = m.RegisterCallback(func(_ context.Context, o metric.Observer) error {
		h.mu.RLock()
		defer h.mu.RUnlock()

		total := float64(h.swapTotal)
		swapStates := []struct {
			state string
			bytes int64
		}{
			{"used", h.swapUsed},
			{"free", h.swapFree},
			{"cached", h.swapCached},
		}
		for _, s := range swapStates {
			attr := metric.WithAttributes(attribute.String("state", s.state))
			o.ObserveInt64(usageCounter, s.bytes, attr)
			o.ObserveFloat64(utilGauge, float64(s.bytes)/total, attr)
		}

		o.ObserveInt64(faultsCounter, h.pageFaultsMajor,
			metric.WithAttributes(attribute.String("type", "major")))
		o.ObserveInt64(faultsCounter, h.pageFaultsMinor,
			metric.WithAttributes(attribute.String("type", "minor")))

		pageOps := []struct {
			direction string
			typ       string
			count     int64
		}{
			{"page_in", "major", h.pageInMajor},
			{"page_out", "major", h.pageOutMajor},
			{"page_in", "minor", h.pageInMinor},
			{"page_out", "minor", h.pageOutMinor},
		}
		for _, op := range pageOps {
			o.ObserveInt64(opsCounter, op.count,
				metric.WithAttributes(
					attribute.String("direction", op.direction),
					attribute.String("type", op.typ),
				))
		}
		return nil
	}, usageCounter, utilGauge, faultsCounter, opsCounter)
}

// ---- simulation tick ----

// tick advances the simulation by one interval, updating all state under the
// write lock. It is called by the collection goroutine before Collect().
func (h *HostSimulator) tick(interval time.Duration) {
	h.mu.Lock()
	defer h.mu.Unlock()

	secs := interval.Seconds()
	rng := h.rng

	// CPU: small random walk on utilization fractions, accumulate time
	for i := range h.cpus {
		nudge := func(v, lo, hi float64) float64 {
			v += (rng.Float64() - 0.5) * 0.03
			if v < lo {
				v = lo
			}
			if v > hi {
				v = hi
			}
			return v
		}
		h.cpus[i].util[0] = nudge(h.cpus[i].util[0], 0.001, 0.80) // user
		h.cpus[i].util[1] = nudge(h.cpus[i].util[1], 0.001, 0.40) // system
		rest := h.cpus[i].util[0] + h.cpus[i].util[1] +
			h.cpus[i].util[3] + h.cpus[i].util[4] +
			h.cpus[i].util[5] + h.cpus[i].util[7]
		if rest > 0.98 {
			rest = 0.98
		}
		h.cpus[i].util[2] = math.Max(0, 1.0-rest) // idle
		for j := range h.cpus[i].time {
			h.cpus[i].time[j] += h.cpus[i].util[j] * secs
		}
	}
	h.recomputeLoadAvg()

	// Memory: slow drift (±1% of total per interval)
	drift := int64(float64(h.memTotal) * (rng.Float64() - 0.5) * 0.02)
	h.memUsed = clamp64(h.memUsed+drift, h.memTotal/10, h.memTotal*85/100)
	h.memFree = h.memTotal - h.memUsed - h.memCached - h.memBuffered -
		h.memSlabReclaimable - h.memSlabUnreclaimable
	if h.memFree < 0 {
		h.memFree = 0
	}

	// Disk IO: random increments per second
	for _, dev := range h.diskDevices {
		d := h.disks[dev]
		d.readBytes += rng.Int63n(50_000_000) * int64(secs)
		d.writeBytes += rng.Int63n(20_000_000) * int64(secs)
		d.readOps += rng.Int63n(2000) * int64(secs)
		d.writeOps += rng.Int63n(1000) * int64(secs)
		d.ioTimeSecs += float64(rng.Int63n(100)) / 1000.0 * secs
		d.opTimeSecs[0] += float64(rng.Int63n(50)) / 1000.0 * secs
		d.opTimeSecs[1] += float64(rng.Int63n(50)) / 1000.0 * secs
		d.pending = rng.Int63n(8)
	}

	// Network IO
	for _, dev := range h.netDevices {
		n := h.nets[dev]
		n.rxBytes += rng.Int63n(10_000_000) * int64(secs)
		n.txBytes += rng.Int63n(5_000_000) * int64(secs)
		n.rxPackets += rng.Int63n(10_000) * int64(secs)
		n.txPackets += rng.Int63n(8_000) * int64(secs)
		if rng.Float64() < 0.005 {
			n.rxErrors++
		}
		if rng.Float64() < 0.002 {
			n.txErrors++
		}
	}
	h.netConns = clamp64(h.netConns+rng.Int63n(21)-10, 5, 2000)

	// Processes
	h.procSleeping = clamp64(h.procSleeping+rng.Int63n(5)-2, 10, 500)
	h.procRunning = clamp64(rng.Int63n(int64(h.cpuLogical)*2)+1, 1, int64(h.cpuLogical*4))
	h.procZombie = clamp64(h.procZombie+rng.Int63n(3)-1, 0, 20)
	h.procCreated += rng.Int63n(50)

	// Paging
	h.pageFaultsMajor += rng.Int63n(5)
	h.pageFaultsMinor += rng.Int63n(5000)
	h.pageInMinor += rng.Int63n(1000)
	h.pageOutMinor += rng.Int63n(500)

	// Swap drift
	swapDrift := int64(float64(h.swapTotal) * (rng.Float64() - 0.5) * 0.005)
	h.swapUsed = clamp64(h.swapUsed+swapDrift, 0, h.swapTotal)
	h.swapFree = h.swapTotal - h.swapUsed
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
