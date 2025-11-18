# Proposed Bradesco Demo Flow

# Onboarding Telemetry

## Onboarding a new host (Windows ARM)

### Script

1) Show Collector Config on Windows ARM
2) Start Collector and Windows log generator
3) Show logs coming into Streams from Windows
4) Partition logs with Streams AI
5) Parse logs with Streams AI
6) Setup significant events with Streams AI ?
7) In Discover, make graph of http status codes
8) Add to dashboard
9) Create alert from graph in dashboard

### Objectives

* 2.5
    * Support for Windows operating system (ARM architecture) to collect OS metrics and identify technologies running on the host

* 6.19
    * Ability to configure alerts directly from dashboards

* 10.6
    * Allow threshold changes using natural language.

* 10.7
    * Enable the creation of dashboards using natural language.

# Interacting with Data

## Working with Log Data

### Script

1) Show logs in Discover
2) open a log line
3) Use AI Assistant to look for neighboring logs
4) Go to APM and view logs for a trace
5) Note email address in log
6) Create ingest pipeline with REDACT processor
7) Show email address is now redacted

### Objectives

* 3.13
    * Support for masking sensitive data

* 4.10
    * Allow the visualization of neighboring logs

## Working with Metrics

### Script

1) show otel metrics from linux kubernetes hosts in hosts UX
2) show kubernetes dashboards
3) setup ML on host cpu

### Objectives

* 6.28
    * Support for preformatted visualization with key metrics based on OpenTelemetry, using data from OpenTelemetry collectors

# Working with Dashboards

### Scripts

1) Show Dashboard Access
2) Run Workflow to tag old dashboards
3) Delete old dashboards
4) Export dashboards from one cluster, import to another

### Objectives

* 6.10
    * Enable tracking the usage (access/popularity) of dashboards

* 6.11
    * Allow decommissioning dashboards that have not been used for a certain period

* 6.29
    * Migration of dashboards between different tenants/instances

# Working with Alerts

### Script

1) setup alert on host CPU threshold
2) set alert export to servicenow
3) use AI to modify alert
4) show active alerts
5) we are doing maintenance, so setup maintenance window

### Objectives

* 7.5
    * Integration with ServiceNow for alert delivery

* 7.3
    * Definition of dynamic thresholds (baseline-based)

* 7.14
    * Alert management by severity and priority

* 7.6
    * Allow alert suppression per period (maintenance window) per service

* 8.7
    * Native integration with ServiceNow