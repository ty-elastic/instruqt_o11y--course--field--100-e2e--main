
Tracing
===

# Tail-Based Sampling (TBS)

All traces are currently flowing through a set of Collectors configured for TBS. Architecturally, traces flow from the k8s cluster gateway collector to a set of Load Balancing Collectors to a set of Sampling Collectors. The Load Balancing Collectors route all spans related to the same trace to the same Sampling Collector.

## How does this work?

1. Open the [button label="OTel YAML"](tab-5) Instruqt tab
2. Navigate to `tbs/tbs.yaml`

# OTel Profiling

## Setup

Do this before you begin the demo.

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `Test`
3. Open `Flags`, select `Test New Hashing Algorithm` and click `SUBMIT`

## Dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards` > `Profilingmetrics`

## How does this work?

1. Open the [button label="OTel Operator YAML"](tab-5) Instruqt tab
2. Navigate to `profiling/profiler.yaml`

Note the OTel Collector configuration with the `profiling` receiver and `profilingmetrics` connector.
