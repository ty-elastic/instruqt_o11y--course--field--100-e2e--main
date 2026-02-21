Tracing
===

# OTel Profiling

## Setup

Do this before you begin the demo.

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `Test`
3. Open `Flags`, select `Test New Hashing Algorithm` and click `SUBMIT`

## Dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Infrastructure` > `Hosts`
3. Select host `k3s`
4. Select `Dashboards` tab

## How does this work?

1. Open the [button label="OTel Operator YAML"](tab-5) Instruqt tab
2. Navigate to `profiling/profiler.yaml`

Note the OTel Collector configuration with the `profiling` receiver and `profilingmetrics` connector.