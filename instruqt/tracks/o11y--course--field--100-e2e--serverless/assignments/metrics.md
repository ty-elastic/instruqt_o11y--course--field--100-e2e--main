
Metrics
===

# Metrics Discovery

The goal of this demo is to demonstrate that the metrics experience in Elastic is optimized to derive value with just a few clicks, competitive with other products.

## Metrics Discovery in Grafana

> [!NOTE]
> Typically, you would demo the Grafana comparison only if the customer is an existing Prometheus/Grafana user.

We are sending the same set of node.js metrics to both Prometheus/Grafana and Elasticsearch.

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

## Metrics Discovery in Kibana

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
TS metrics-* | WHERE data_stream.dataset == "prometheusreceiver.otel"
```

Note how easy it is to quickly visualize a large set of related metrics.

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

### Create Alert Rule

Once on the dashboard, click the `Explore in Discover` icon at the top of the `http_requests_total` visualization to jump back to Discover.

1. Modify the ES|QL to prepare it for an alert:
```
TS metrics-*
  | WHERE data_stream.dataset == "prometheusreceiver.otel"
  | STATS http_requests_rate = SUM(RATE(http_requests_total)) BY BUCKET(@timestamp, 1, ?_tstart, ?_tend)
  | WHERE http_requests_rate > 0
```
2. Click the `Alerts` menu in the upper-right
3. Select `Create search threshold rule` from the menu

Note how the query was auto-populated from your Discover session.

4. Set `Set the time window` to  `1 minute`
5. Click `Create rule`

# PROMQL Support

The goal of this demo is to demonstrate our support for PROMQL to help teams using Grafana and PROMQL migrate to Kibana.

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

# OOTB OTel Dashboards

The goal of this demo is to show OOTB support for popular, native OTel metrics. Elasticsearch will automatically add OOTB dashboards when it recognizes the relevant OTel metric data.

## PostgreSQL

### Dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[Metrics PostgreSQL OTel] Database Overview`

## MySQL

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[MySQL OTel] Overview`

## nginx

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards`
3. Open dashboard `[Metrics Nginx OTEL] Overview`

# Advanced ES|QL

The goal of this demo is to demonstrate analytics that go beyond what can be done with OOTB Dashboards.

## Comparing latency across flows

ES|QL is a powerful language for performing metric analytics. Let's say you are testing an alternative code path which performs similar tasks, but is implemented with a different technology stack. How can you compare performance between the two?

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

## AI Agent

The goal of this demo is to demonstrate how you can use an AI Agent to interrogate metrics and cross-correlate with other signals through natural language.

### Trigger Alert

> [!NOTE]
> Don't need to show this setup step to customers

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `ERROR`
3. Open `DB`, select `Generate errors` and click `SUBMIT`

> [!NOTE]
> There isn't a need to wait for the alert to fire; just head right to the next step

### Observing the problem

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards` > `[Metrics PostgreSQL OTel] Database Overview`
3. Scroll down to `Transactions Committed vs Rolled Back`
4. Wait for `rolled back` series to go to non-zero

### AI-Agent Assist

1. Click the `AI Agent` button in the upper-right corner of the dashboard
2. Select `Observability Agent` (important)
3. Ask
```
are the rolled back transactions causing trace failures?
```

Note that Elastic automatically queried APM metric sources with correlating information from this dashboard (e.g, timestamp).

4. Ask
```
did the rolled back transactions cause a spike in log rate?
```

5. Ask
```
were there any logs which explain the change in rolled back transactions?
```

# Custom Metrics

We are generating a variety of OTel custom metrics from our `trader` application. We want to create a dashboard and agent which leverages those metrics to monitor the health of our trading operations.

## [optional] How does this work?

1. Open the [button label="Code"](tab-3) Instruqt tab
2. Navigate to `trader/app.py`
3. Note the code which initializes the OTel metrics (line 58) and the code which sets the metrics (around line 152)

## Dashboarding

Let's create a few visualizations. First, let's create a visualization with lens:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
TS metrics.trader
```
5. Enter the following in the `Search metric` bar
```
shares_traded_per_customer
```
6. Click `Explore` in the upper-right corner of the `shares_traded_per_customer` graph
7. Edit and execute the ES|QL query:
```
TS metrics.trader
  | STATS avg_shares_traded = AVG(metrics.shares_traded_per_customer) BY BUCKET(@timestamp, 100, ?_tstart, ?_tend), symbol
```
8. Click on the `Save visualization` (Disk) icon in the upper-right of the graph
9. Set the `Title` to:
```
Shares Traded Per Symbol
```
10. Under `Add to dashboard` select `New`
11. Click `Save and go to dashboard`

Now let's use Lens to add another graph:

1. Click `Add` in the upper-right and select `Visualization`
2. Set the `Data view` to `metrics.trader`
3. 

- ML
- agent builder w/ tools
- dyn dash
