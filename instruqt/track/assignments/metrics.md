
Metrics
===

# Metrics Discovery

The goal of this demo is to show that the metrics experience in Elastic is optimized to derive value with just a few clicks, competitive with other products.

## Metrics Discovery in Grafana

> [!NOTE]
> Typically, you would demo the Grafana comparison only if the customer is an existing Prometheus/Grafana user.

We are sending the same set of node.js metrics to both Prometheus/Grafana and Elasticsearch.

1. Open the [button label="Grafana"](tab-9) tab
2. Navigate to `Drilldown` > `Metrics`
3. Enter the following in the `Search metric` search box:
```
http_requests_total
```
4. Click `Select` in the upper-right of the `http_requests_total` graph
5. Set `Breakdown` > `By label` to `region`
6. Click the `Add to dashboard` control in the upper-right of the `http_requests_total` graph (in the top pane)
7. Click `Open dashboard` in the `Add to dashboard` dialog
8. Click `Save dashboard` in the upper-right
9. Set `Title` to:
```
node.js Monitor
```
10. Click `Save`

## Metrics Discovery in Kibana

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
TS metrics-prometheusreceiver.otel-default | WHERE data_stream.dataset == "prometheusreceiver.otel"
```

> [!NOTE]
> Note how easy it is to quickly visualize a large set of related metrics.

5. Click the search (magnifying glass) icon in the upper-right of the graph area and enter the following in the `Search metric` field:
```
http_requests_total
```

> [!NOTE]
> Hover over the series in the graph and note that Kibana automatically detected that this is a monotonically increasing counter and automatically applied a rate (derivative) transformation.

6. Click `No dimension selected` and select `region`
7. Click on the three vertical dots in the upper right of one of the `http_requests_total` graphs
8. Select `Copy to dashboard`
9. Click `New` in the `Save Lens visualization` dialog
10. Click `Save and go to Dashboard`
11. Click `Save in the upper-right
12. Set `Title` to: 
```
node.js Monitor
```
13. Click `Save`

### Create Alert Rule

We can easily turn a metric visualization into an actionable alert rule.

1. From the dashboard, click the three dots in the upper-right of the `http_requests_total` graph
2. Select `Create alert rule`
3. Modify the last line of ES|QL (containing `[THRESHOLD]`) to alert when the http_requests_total rate is less than 3 per second:
```
| WHERE _sum_rate_http_requests_total < 3
```
4. Click `Next` to move onto `Actions`
5. Click `Add action` and select `Cases`
6. Click `Next` to move onto `Details`
7. Set `Rule name` to `http_requests_total < 3`
8. Click `Create rule`

# PROMQL Support

The goal of this demo is to show how teams using Grafana and PROMQL can feel at home using PROMQL in Elasticsearch.

## PROMQL in Grafana

> [!NOTE]
> Typically, you would demo the Grafana comparison only if the customer is an existing Prometheus/Grafana user.

1. Open the [button label="Grafana"](tab-9) tab
2. Navigate to `Explore`
3. Click `Code` toggle (on the right)
4. Enter the following into the `Enter a PromQL query...` field:
```
sum by (region) (rate(http_requests_total[5m]))
```
5. Click `Run query` (circular arrows)

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
3. Note that `router` is dividing transactions between a Java/PostgreSQL stack (`recorder-java` > `postgresql`) and a go/mySQL stack (`recorder-go` > `mysql`)
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
6. Select `Unstacked` under `Visualization parameters`
7. Click `Apply and close`

This lets us nicely examine the overall difference in latency between the 2 paths along with a comparative breakdown of the individual components which contribute to the overall latency.

# SLOs

SLOs are critical for monitoring metrics. SLOs allow metrics to naturally ebb and flow a little at scale while still holding organizations (and technology) accountable.

## Creating a SLO to monitor our APM Services

Elastic makes it easy to create SLOs for OOTB metrics like APM Availability.

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `SLOs`
3. Click `Create SLO`
4. Under `Choose the SLI type`, select `APM availability`
5. Under `Service name`, select `All`
6. Under `Group by`, select `service.name` and `cloud.region`

This will monitor all APM services. If there is a violation, an alert will be generated specific to a service (`service.name`) and region (`region`).

7. Under `Set objectives` you could change the target SLO parameters (e.g., 99.9% uptime over 7 days)
8. In the `Describe SLO` section, enter the following as the `SLO Name`:
```
Service Availability
```
9. Enter `example` in `Tags`
10. Click `Create SLO`

## Setting Actions

Now that we have a SLO, we can define what happens when that SLO is breached.

1. Click on the `Service Availability` SLO you just created
2. Click on the `Actions` menu and select `Manage burn rate rule`

Here, you could define thresholds for actions based on how quickly you are burning through the error budget.

3. Click on `Actions` tab
4. Click on `Add action`
5. Select `Cases`

This will automatically create a case whenever this SLO breaches the lowest burn rate threshold (i.e., days before we violate the SLO).

6. Click on `Add action`
7. Select `Elastic-Cloud-SMTP`
8. In the `To` field, enter `sre@example.com`
9. Click the button to the right of the `Subject` field
10. Select `context.sloName`
11. Click `Settings` tab
12. Under `Action frequency`, set `For each alert` to `On custom action intervals`
13. Set `Run when` to `Critical`
14. Click `Save changes`

This will automatically page a SRE if and only if we have breached the highest burn rate threshold (i.e., hours before we violate the SLO).

# AI Agent Assist

The goal of this demo is to demonstrate how you can use an AI Agent to interrogate metrics and cross-correlate with other signals through natural language.

## Trigger Errors

> [!NOTE]
> There isn't a need to _show_ customers this step.

First, let's create a database problem:
1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `ERROR`
3. Open `DB`, select `Generate errors` and click `SUBMIT`

## Observing the problem

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards` > `[Metrics PostgreSQL OTel] Database Overview`
3. Change the time picker to be `Last 15 minutes` (if not already)
4. Scroll down to `Transactions Committed vs Rolled Back`
5. Wait for `rolled back` series to be non-zero for a minute

## Assisted RCA

> [!WARNING]
> Ensure you are issuing questions against the `Observability Agent`

1. Click the `AI Agent` button in the upper-right corner of the dashboard
2. Select `Observability Agent`
3. Execute the following question:
```
are the rolled back transactions causing trace failures?
```
4. You can open the reasoning step to see the steps the AI Agent is taking to answer your query

> [!NOTE]
> Note that Elastic automatically queried APM metric sources with correlating information from this dashboard (e.g, timestamp).

4. Execute the following question:
```
did the rolled back transactions cause a spike in log rate?
```
5. Execute the following question:
```
were there any logs which explain the change in rolled back transactions?
```
6. Execute the following question:
```
can you create a graph of that log rate spike?
```

# Custom Metrics

We are generating a variety of OTel custom metrics from our `trader` application. The goal of this demo is to create a custom dashboard and agent which leverages those metrics to monitor the health of our trading operations.

## Dashboarding

Let's create a few visualizations. First, let's create a visualization with lens:

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover`
3. Enter `ES|QL` mode (if Discover is not yet in `ES|QL` mode)
4. Execute the following ES|QL:
```
TS metrics-trader
```
5. Click the search (magnifying glass) icon in the upper-right of the graph area and enter the following in the `Search metric` field:
```
shares_traded_per_customer
```
6. Click `Explore` in the upper-right corner of the `shares_traded_per_customer` graph
7. Edit and execute the ES|QL query (to properly name the vertical axis and breakdown by symbol):
```
TS metrics-trader
  | STATS avg_shares_traded = AVG(metrics.shares_traded_per_customer) BY BUCKET(@timestamp, 100, ?_tstart, ?_tend), symbol
```
8. Click on the pencil icon in the upper-right of the graph and select the `Line` graph (if not already selected)
9. Click on the `Save visualization` (Disk) icon in the upper-right of the graph
10. Set the `Title` to:
```
Shares Traded Per Symbol
```
11. Under `Add to dashboard` select `New`
12. Click `Save and go to dashboard`

Now let's use Lens to add another graph to our dashboard:

1. Click `Add` in the upper-right and select `Visualization`
2. Set the `Data view` to `metrics-trader`
3. Find the field `share_price` and drag it to the `Vertical axis`
4. Find the field `symbol` and drag it to `Breakdown`
5. Find the field `@timestamp` and drag it to `Horizontal axis`
6. Set the visualization type to `Line`
7. Click `Save and return`
8. Click `Save` in the upper-right of the dashboard
9. Set `Title` to:
```
Trading
```
10. Click `Save`

## Machine Learning

Let's create a ML job to look for suspicious trade activity.

> [!NOTE]
> A pre-populated ML job has already been created for you. This step is simply to show the customer how relatively easy it is to create ML jobs on custom data. You could optionally skip it.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Machine Learning` > `Overview`
3. Click `Manage jobs`
4. Click `Create job`
5. In `Select data view`, select `metrics-trader`
6. Click `Population`
7. Click `Use full data`
8. Click `Next`
9. For `Population field`, select `attributes.customer_id`
10. Under `Add metric`, select `Mean(metrics.shares_traded_per_customer)`
11. Under `Split data`, select `attributes.symbol`
12. Click `Next`
13. Under `Job ID`, name the job:
```
example_ml_job
```
14. Click `Next` on the `Population` step
14. Click `Next` on the `Validation` step
15. Click `Create job`

### Generate anomalous trading behavior

> [!NOTE]
> There isn't a need to _show_ customers this step.

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `TRADE`
3. Open `Force Trade`
4. `Customer ID` to `q.bert`
5. Set `Shares` to `10000`
7. Click `SUBMIT` 5 (or so) times

### Add our swim lane graph to our dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards` > `Trading`
3. Click `Add` in the upper-right and select `+ New panel`
4. Select `Anomaly Swim Lane`
5. Select `shares_traded_anomalies` (this is the job we pre-created which has been running for awhile)

> [!WARNING]
> Please use the pre-populated `shares_traded_anomalies` job (it has been running for awhile), not the `example_ml_job` job you just created.

6. Click `View by` and set `View by` field to `customer_id` (might be `attributes.customer_id`)
7. Click `Confirm`

### Add alerts to our dashboard

1. Click `Add` in the upper-right and select `+ New panel`
2. Select `Alerts`
3. Set `Filter by` to `Rule tags`
4. Set `Rule tags` to `trading`
5. Click `Save`

Wait a minute or so and look for `q.bert` and note that it is an anomaly.

Note the active alert for `q.bert`.

## Using a Custom Agent to interrogate our data

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards` > `Trading`
3. Click `AI Agent` in the upper-right
4. Click the `+` button in the upper-left of the AI Agent fly-out to start a new conversation
5. Select the `Trading Operator` Agent

> [!WARNING]
> Ensure you are issuing questions against the `Trading Operator`

5. Execute the following question:
```
are there any trading anomalies I should be aware of?
```
6. Execute the following question:
```
can you graph q.bert's trading behavior?
```
7. Execute the following question:
```
is there a runbook I should follow?
```
8. Execute the following question:
```
can you create a case to capture this issue including a summary of this conversation?
```

### How does this work?

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Agents`
3. Select `More` from the upper-right
4. Select `View all agents`
5. Select the `Trading Operator` agent

> [!NOTE]
> Note the custom prompt.

6. Select the `Tools` tab

> [!NOTE]
> Note the selection of tools available to the agent.

## Custom Cases

We can use cases to track work related to custom business metrics.

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Cases`
3. Open the newly created case

> [!NOTE]
> Note that the case was automatically opened and amended per our work with the agent.

# Agentic RCA

If you'd like to demonstrate metric-driven (alert) agentic RCA which looks at logs, traces, and metrics, see [Agentic RCA](section-agentic-rca).
