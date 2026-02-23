
Metrics
===

# Metrics Discovery

The goal of this demo is to demonstrate that the metrics experience in Elastic is optimized to derive value with just a few clicks.

## Metrics Discovery in Grafana (optional)

> [!NOTE]
> Typically, you would demo the Grafana comparison only if the customer is an existing Prometheus/Grafana user.

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

## Metrics Discovery in Kibana

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

# PROMQL

## PROMQL in Grafana

> [!NOTE]
> Typically, you would demo the Grafana comparison only if the customer is an existing Prometheus/Grafana user.

1. Open the [button label="Grafana"](tab-9) tab
2. Navigate to `Explore`
3. Click `Code` toggle (on the right)
4. Enter the following into the `Enter a PromQL query...` field
```
sum by (region) (rate(http_requests_total[5m]))
```
5. Click `Run query`

## PROMQL in Kibana

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
PROMQL index=metrics-* start=?_tstart end=?_tend step=5m sum by (region) (rate(http_requests_total[5m]))
```

> [!NOTE]
> You can copy and paste `sum by (region) (rate(http_requests_total[5m]))` from Grafana into Kibana for greater effect.

Note the same result as in Grafana.

# OOTB OTel Dashboards

## PostgreSQL

### Dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[Metrics PostgreSQL OTel] Database Overview`

### How does this work?

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgresql.yaml`

Note the OTel Collector configuration with the `postgresql` receiver.

## MySQL

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[MySQL OTel] Overview`

### How does this work?

To collect mysql metrics, we use a sidecar vanilla OTel Collector configured with the `mysql` receiver.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `mysql.yaml`

Note the OTel Collector configuration with the `mysql` receiver.

## nginx

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[Metrics Nginx OTEL] Overview`

### How does this work?

To collect mysql metrics, we use a sidecar vanilla OTel Collector configured with the `mysql` receiver.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `proxy.yaml`

Note that we use the creator receiver pattern to tell the daemonset OTel Collector to invoke the `nginx` receiver

# Powerful Analytics

ES|QL is a powerful language for performing metric analytics.

## Comparing 2 execution paths

Let's say you are testing an alternative code path which performs similar tasks, but is implemented with a different technology stack. How can you compare performance?

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`
3. Note that `router` is dividing transactions between a Java/PostgreSQL stack and a go/mySQL stack.
4. Click on the `router` service and select `Service Details`
5. Scroll down to the bottom and observe `Dependencies` and note the differences in average latency

But what if we want to break down and compare the individual latency components?

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
FROM traces-* 
| WHERE service.name == "recorder-java" OR service.name == "recorder-go"
| FORK
  (WHERE transaction.name == "POST /record"
  | EVAL t_duration_ms = transaction.duration.us / 1000
  | STATS avg_t_latency = AVG(t_duration_ms) BY service.name)
  (WHERE span.type == "db"
  | EVAL s_duration_ms = span.duration.us / 1000
  | STATS latency_per_trace = SUM(s_duration_ms) BY trace.id, service.name
  | STATS avg_db_latency = AVG(latency_per_trace) BY service.name)
  (WHERE span.type == "external"
  | EVAL s_duration_ms = span.duration.us / 1000
  | STATS latency_per_trace = SUM(s_duration_ms) BY trace.id, service.name
  | STATS avg_http_latency = AVG(latency_per_trace) BY service.name)
| KEEP avg_t_latency, avg_db_latency, avg_http_latency, service.name
```
5. Click on the pencil icon to the right of the resulting graph
6. Select `Unstacked`
7. Click `Apply and close`

This lets us nicely examine the overall difference in latency between the 2 paths along with a comparitive breakdown of the individual components which contribute to the overall latency.

## Correlating signals

### Setup

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `ERROR`
3. Open `GC`, select `Thrash Garbage Collector` and click `SUBMIT`

(wait a minute)

### Observing the problem

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`
3. Note that `router` is dividing transactions between a Java/PostgreSQL stack and a go/mySQL stack.
4. Click on the `router` service and select `Service Details`
5. Scroll down to the bottom and observe `Dependencies` and note the differences in average latency



```
was there a change in host cpu usage that corresponds to this elevated latency?
```




# Custom Metrics

- OTEL
- prom
