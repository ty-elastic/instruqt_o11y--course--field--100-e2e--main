Metrics Discovery
===

(add the Grafana comparison if this customer is an existing Grafana user)

# Metrics Discovery in Grafana (optional)

1. Open the [button label="Grafana"](tab-9) tab
2. Navigate to `Drilldown` > `Metrics`
3. Enter the following in the `Search metric` bar
```
http_requests_total
```
4. Click `Select`
5. Set `Breakdown` > `By label` to `region`
6. Click the `Add to dashboard` control in the upper-right of the `http_requests_total` graph
7. Click `Open dashboard` in the `Add to dashboard` dialog

(add alert rule?)

# Metrics Discovery in Kibana

Now let's mirror that experience in Kibana.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
TS metrics-*
```

Note how easy it is to quickly visualize a large set of metrics.

Now let's find our metric:
1. Enter the following in the `Search metric` bar
```
http_requests_total
```

Note that Kibana detected that this is a monotonically increasing counter and automatically applied a rate (derivative) transformation.

2. Click `No dimension selected` and select `region`
3. Click on the three vertical dots in the upper right of one of the `http_requests_total` graphs
4. Select `Copy to dashboard`
5. Click `New` in the `Save Lens visualization` dialog
6. Click `Save and go to Dashboard`

(add alert rule?)

PROMQL
===

(generally only applicable if customer is coming from prometheus/grafana)

# PROMQL in Grafana

1. Open the [button label="Grafana"](tab-9) tab
2. Navigate to `Explore`
3. Click `Code` toggle (on the right)
4. Enter the following into the `Enter a PromQL query...` field
```
sum by (region) (rate(http_requests_total[5m]))
```
5. Click `Run query`

# PROMQL in Kibana

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
PROMQL index=metrics-* start=?_tstart end=?_tend step=5m sum by (region) (rate(http_requests_total[5m]))
```
(note, you can copy and paste `sum by (region) (rate(http_requests_total[5m]))` from Grafana into Kibana for greater effect)

Note the same result as in Grafana.

OOTB OTel Dashboards
===

# PostgreSQL

## Dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[Metrics PostgreSQL OTel] Database Overview`

## How does this work?

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgresql.yaml`

Note the OTel Collector configuration with the `postgresql` receiver.

# MySQL

Here, we will demo Elastic's ability to automatically load content packs (dashboards) in response to observing relevant incoming OTel metrics.

First, we need to show that the dashboards for MySQL do not yet exist in our cluster:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Search for `[MySQL OTel] Overview`

Note that this dashboard is not yet loaded.

Let's also show the current service architecture:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`

Note that all trades flow through `recorder-java` to `postgresql`

## Enable MySQL Path

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `Test`
3. Open `Flags`, select `Test MySQL Database` and click `SUBMIT`

This will cause the `router` service to start directing trade requests toward a MySQL database path (via `recorder-go`).

Let's see how this changes the service architecture:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`

Note that all trades are now split between `postgresql` (for `trading-emea` region) and `mysql` (for `trading-na` region).

## Dynamic Content Pack Loading

When we send metrics collected from mysql via an OTel Collector, Elasticsearch dynamically loads the relevant dashboards:

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[Metrics PostgreSQL OTel] Database Overview`

Note that is dashboard dynamically loaded.

## How does this work?

To collect mysql metrics, we use a sidecar vanilla OTel Collector configured with the `mysql` receiver.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `mysql.yaml`

Note the OTel Collector configuration with the `mysql` receiver.

# nginx

ES|QL Analytics
===

