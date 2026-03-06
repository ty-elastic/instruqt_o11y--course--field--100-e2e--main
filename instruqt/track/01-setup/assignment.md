---
slug: setup
id: x6ybpvkupwdi
type: challenge
title: Setup
tabs:
- id: 30sfsev9u4tn
  title: Elastic
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 9100
  custom_request_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
  custom_response_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
- id: 9ncb6x7pp1af
  title: Elastic-Breakout
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 9100
  new_window: true
  custom_response_headers:
  - key: Content-Security-Policy
    value: 'script-src ''self'' https://kibana.estccdn.com; worker-src blob: ''self'';
      style-src ''unsafe-inline'' ''self'' https://kibana.estccdn.com; style-src-elem
      ''unsafe-inline'' ''self'' https://kibana.estccdn.com'
- id: xdhebe0j1k32
  title: Trader (NA)
  type: service
  hostname: k3s
  path: /
  port: 8082
- id: gs7qple23oel
  title: Code
  type: code
  hostname: k3s
  path: /workspace/workshop/src
- id: ppng432dup3n
  title: K8s YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/k8s/yaml
- id: tlshb9tdxbnl
  title: OTel Operator YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/agents
- id: 2hojslv7ro1o
  title: Services Host
  type: terminal
  hostname: k3s
- id: m7ad4gtm81hz
  title: GitHub Issues
  type: website
  url: https://github.com/ty-elastic/instruqt_o11y--course--field--100-e2e--main/issues
  new_window: true
- id: y1yhe9g7sec4
  title: Slides
  type: website
  url: https://docs.google.com/presentation/d/11lkZIvLNwWR8Tm6edCsPTIImypjKiylzwhOAa8527EM/edit?usp=drive_link
  new_window: true
- id: wumrx3hkq9o8
  title: Grafana
  type: service
  hostname: k3s
  path: /
  port: 3000
  new_window: true
- id: 5w0vqkjzjmak
  title: ES Host
  type: terminal
  hostname: es3-api
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

This is intended to be an "all-in-one" Observability demo and exploration environment with lots of rich data to work with against a fully-enabled, dedicated (and ephemeral) Serverless Elasticsearch instance.

> [!WARNING]
> This is not intended to be a customer-facing workshop.

> [!WARNING]
> The content will likely change (improve) over time, so always take the time to retest your planned demo before going before a customer.

> [!NOTE]
> Share the [button label="Elastic-Breakout"](tab-1) tab (and possibly the [button label="Grafana"](tab-9) tab) with the customer. While the assignment will reference the [button label="Elastic"](tab-0) tab, you should invoke the instructions against the shared [button label="Elastic-Breakout"](tab-1) tab.

In the following sections, you will find various walk-throughs and notes in the assignment. These are for your benefit as a SA. Familiarize yourself with the flows, play around, and perhaps customize to your liking.

* [Agentic RCA](section-agentic-rca)
* [Logs](section-logs)
* [Metrics](section-metrics)
* [Tracing](section-tracing)
* [Workflows](section-workflows)

> [!NOTE]
> Pick and choose the demos and order for your particular customer. You do not need to show every demo or sub-demo.

Supporting slides (where available) can be found [here](https://docs.google.com/presentation/d/11lkZIvLNwWR8Tm6edCsPTIImypjKiylzwhOAa8527EM/edit?usp=drive_link) .


___


Agentic RCA
===

# Alert Correlation, Agentic Root Cause Analysis, and HIL Remediation

## Goals
* Show fully agentic alert correlation and multi-signal RCA with context

## Technical Setup

Perform these steps before you start the demo.

### Steady-State

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Alerts`
3. Wait until there are no active alerts (service startup will trigger some failure alerts)

### Generate Alerts

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `ERROR`
3. Open `DB`, select `Generate errors` and click `SUBMIT`
4. Open the [button label="Elastic"](tab-0) Instruqt tab
5. Navigate to `Alerts`
6. Wait for new alerts to appear

### Trigger Workflows

Be sure to wait until the new alerts (`APM Failure Rule`) fire before executing the `alert_process` workflow.

While you could trigger the `alert_process` workflow during the demo, I would recommend triggering it ahead of the demo rather than waiting for it to complete (which might take 5 minutes or so). During the demo, you can walk through the executed steps if the customer is interested in observing the workflows step-by-step.

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `alert_process` workflow
4. Manually execute it

Once the `alert_process` completes alert correlation, it will automatically start `case_process` to perform the RCA.

## Demo

### Introduction

We have a set of microservices which implement a financial trading application:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`

Our database implements SQL data constraints which validate certain parameters, including that the number of shares being traded is a positive value:
1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgresql.yaml`
3. Note that `CREATE TABLE` (line 78) assigns constraints to specific fields

We are intentionally introducing errors into the system whereby all of the trades coming from the `EU` region will be trying to trade a negative number of shares and violate the database constraints.

### Manual Debugging

Let's first debug this problem with minimal AI assistant as an SRE might do today:

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Alerts` (note the 3 possibly related alerts)
3. Choose one of the new alerts and select `View in app`
4. Scroll down to `Transactions` and select the `POST ...` transaction (it will be named differently depending on which service you selected)
5. Enter the following into the `Search transactions` bar at the top of the page:
```
status.code : "Error"
```
6. Scroll down to the waterfall graph and note the rippling error from database `INSERT` back up through the `trader` application
7. Click `View related error` on the failed `INSERT trades.trades` span
8. Click on the error message `ERROR: new row for relation "trades" violates check constraint "trades_share_price_check"`
9. Open `What's this error?` to show how the AI Assistant can help make sense of this error

While this was a helpful analysis, we still have 2 additional alerts to triage. They are possibly related, but we would have to repeat this exercise at least in part to confirm that hypothesis. Additionally, once we confirm these alerts are related, how can we communicate that association to other SREs.

Let's look at our dependency map to appreciate how a database error could trigger multiple alerts:

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`
3. Note the dependency chain leading back from `postgresql`. Database validation errors will propagate backwards through `recorder-java`, `router`, and `trader`.

### Agentic Alert Correlation

Imagine a larger system where a simple problem manifests in hundreds of alerts. To avoid triaging each alert individually, we first need to intelligently group related alerts to Cases. We will leverage Workflows, Agent Builder, and Cases.

#### (Optional) How does this work?

We process each alert in a workflow (`alert_process`).

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `alert_process` workflow

For each alert, we call the `alert_correlation` agent whose prompt and tools help it decide if an alert is related to an existing case or not.

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Agents`
3. Click `More` in the upper-right and select `View all agents`
4. Open the `Alert Correlation` agent

Note the custom instructions (prompt) which tell it how to correlate alerts.

5. Click the `Tools` tab (to the right of `Settings`)

Note that we give this agent access to only specific tools to help it focus on its task and execute in a definitive fashion.

Note that we leverage system topology (accessed via the `get_topologies` tool, derived from the `topology_builder` agent) to help understand dependencies when correlating alerts to Cases.

#### (Optional) Alert Correlation Workflow Walkthrough

If the customer is interested in understanding OneWorkflow, you can optionally walk them through the execution steps. I would generally note here that we are working to bring alert correlation into the platform (e.g., we wouldn't expect a customer to write this workflow themselves).

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `alert_process` workflow
4. Click `Executions`
5. Select the latest execution
6. Open `is_workflow_running` > `false` > `foreach_alert` > `0` > `correlate`
7. Click on `Input` and note that we are passing an alert to the `alert_correlation` Agent (`body.input`)
8. Click on `Output` and note for the first alert that it couldn't find an existing case to correlate to (`response.message`)
9. Open `is_workflow_running` > `false` > `foreach_alert` > `0` > `new_or_update_case` > `true` > `create_new_case`
10. Note that we are creating a new case for this alert (`description`)
11. Open `is_workflow_running` > `false` > `foreach_alert` > `0` > `add_alert_to_case`
12. Note that we are adding this alert to the new case

The above creates the case and adds the first alert to it. Now let's look at how additional alerts might be correlated to this alert.

13. Open `is_workflow_running` > `false` > `foreach_alert` > `1` > `correlate`
14. Click on `Input` and note that we are passing an alert to the `alert_correlation` Agent (`body.input`)
15. Click on `Output` and note for the second alert that the Agent correlated this alert to the case we created above (`response.message`)
16. Open `is_workflow_running` > `false` > `foreach_alert` > `1` > `add_comment_to_case`
17. Click on `Input` and note that we are adding this alert to an existing case (`body.comment`)

In the next step, we will have the opportunity to see the reasoning steps the Agent took to correlate these alerts to the same case.

#### View alert correlation results

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Cases`
3. Open the newly created case
4. Click `Attachments` and note that all 3 related alerts were correlated to the same case
5. Click `Activity` and note that when each alert was added, a comment was automated appended indicating a summary of the alert and why it was correlated to this case
6. Click on the `Conversation` link in the comment for an added alert
7. In the AgentBuilder conversation, click on `Completed reasoning` to see all of the steps the agent took to correlate this alert to this case
8. Open up a tool call request/response to better understand the data the agent used to correlate the alert

### Agentic Root Cause Analysis

Now that we've grouped related alerts to Cases, we can perform Root Cause Analysis on the case. We will leverage Workflows, Agent Builder, and Cases.

#### (Optional) How does this work?

We process each case in a workflow (`case_process`).

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `case_process` workflow

For each case, we call the `rca` agent whose prompt and tools help it perform root cause analysis of an issue.

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Agents`
3. Click `More` in the upper-right and select `View all agents`
4. Open the `rca` agent

Note the custom instructions (prompt) which tell it how to perform root cause analysis.

5. Click the `Tools` tab (to the right of `Settings`)

Note that we give this agent access to only specific tools to help it focus on its task and execute in a definitive fashion.

Note that we leverage knowledge (accessed via the `search_knowledgebase` tool) to understand if this issue is known. Note that we leverage lots of OOTB platform and observability tools to gather evidence.

#### (Optional) Root Cause Analysis Workflow Walkthrough

If the customer is interested in understanding OneWorkflow, you can optionally walk them through the execution steps. I would generally note here that we are working to bring agentic RCA into the platform (e.g., we wouldn't expect a customer to write this workflow themselves).

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `case_process` workflow
4. Click `Executions`
5. Select the latest execution
6. Open `is_workflow_running` > `false` > `foreach_case` > `0` > `is_case_unstable` > `false` > `if_needs_update` > `true` > `rca`
7. Click on `Input` and note that we are passing the case to the `rca` Agent (`body`)
8. Click on `Output` and note that we are getting back the root cause analysis (`response.message`)
9. Open `is_workflow_running` > `false` > `foreach_case` > `0` > `is_case_unstable` > `false` > `if_needs_update` > `true` > `add_response_to_existing_case`
10. Click on `Input` and note that we are appending the root cause analysis to the case (`body.comment`)

In the next step, we will have the opportunity to see the reasoning steps the Agent took to perform the root cause analysis.

#### View RCA results

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Observability` > `Cases`
3. Open the case
4. Click `Attachments` and note that all 3 related alerts were correlated to the same case
5. Click `Activity`
6. Click `Show more` if needed to show all of the case comments
7. Note that we appended each step of the reasoning of the RCA Agent to the case as a comment
8. Scroll down to the last comments in the case
9. Note the detailed Root Cause Analysis w/ dependency map, explanation of correlation, and analysis of logs, traces, and metrics
10. Note that the Agent matched this problem with a known issue
11. Where did this issue come from? Open the [button label="GitHub Issues"](tab-7) Instruqt tab and open the corresponding GitHub issue.
12. Note also that the Agent recommended for us to restart the monkey service to resolve this issue

### Continue the Investigation

Once the initial triage is done, SREs may want to deep-dive into the available telemetry to validate the findings of the Agent.

#### Validate the Investigation

1. Starting from the last step, at the bottom of the case, you will find a link to continue investigation or take remedial action
2. In the AgentBuilder conversation, click on `Completed reasoning` (at the top) to see all of the steps the agent took to correlate this alert to this case
3. Open up a tool call request/response to better understand the data the agent used to perform root cause analysis

#### Dig for further evidence

1. Enter the following into the `Ask anything` box at the bottom of the Agent
```
was there a spike in log rate when this issue started occurring?
```
2. Enter the following into the `Ask anything` box at the bottom of the Agent
```
can you update the case with the results of our log rate analysis?
```

After the agent is done, let's verify that the case was updated:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Observability` > `Cases`
3. Open the case
4. Scroll down to the last comments in the case and note that it now includes our log rate analysis

### Remediation

We intentionally make remediation a Human-In-the-Loop (HIL) activity, though of course we could have told our agent to automatically take this step if we wanted. You'll recall that the RCA analysis suggested we could remediate the issue by restarting the `monkey` service. Let's do it!

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Observability` > `Cases`
3. Open the case
4. Scroll down toward the bottom of the case and look for the link to continue investigation or take remedial action
5. Click on the link to enter the Agent
6. Enter the following into the `Ask anything` box at the bottom of the Agent
```
can you restart the monkey service?
```

After the agent has completed the task, let's verify that the service was restarted

1. Open the [button label="Services Host"](tab-6) Instruqt tab
2. Enter the following `kubectl` command:
```bash,run
kubectl -n trading-na get pods
```
3. Note that the `monkey` pod was recently restarted

#### (Optional) How does this work?

Remediation can be achieved by teaching the RCA Agent how to call a Workflow that in turn can call a remote command.

Let's have a look at the RCA Agent:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Agents` (it may be hidden under the `...` menu)
3. Click on `More` in the upper-right and select `View all tools`
4. Enter the following into the search bar
```
remediation
```
5. Click on the `remediation_service_action` tool and note that it calls the `remediation_service_action` workflow

Let's have a look at the `remediation_service_action` workflow:
1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Enter the following into the search bar
```
remediation
```
4. Click on the `remediation_service_action` workflow
5. Note that it makes a HTTP call into our services cluster
6. Click on `Executions`
7. Open the most recent execution
8. Click on `call_remote` and select `Input`
9. Note the http call to restart the `monkey` service

___


Logs
===

# SQL Commentor
Typically, database audit logs cannot easily be associated with traces. Using SQL Commentor, however, it becomes possible to follow a trace all the way from user interaction down to the database audit log.

[SQL Commentor](https://google.github.io/sqlcommenter/) is a library that can be used by Java applications making SQL calls (here, `recorder-java`). SQL Commentor will look for an active OpenTelemetry trace and append the appropriate `traceparent` header as a comment to the SQL query. Most SQL databases (including postgresql) will output the comment as part of the audit log!

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Applications` > `Service map`
3. Select `recorder-java`
4. Select transaction `POST /record`
5. Click on the `Logs` tab under `Trace sample`
6. Note the inclusion of logs from `postgresql`

## How does this work?

We are loading the `recorder-java` service with a custom build of the java SQL commentor library.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `recorder-java.yaml`

The SQL commentor library will automatically add `trace.id` (if its available on the current context) to SQL commands as a comment. We are then parsing that `trace.id` out of the comments and putting it into a first-class `trace.id` field.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgres.yaml`

Note the `regex_parser` operator specific in the `io.opentelemetry.discovery.logs.postgresql/config` annotation.

# OTTL Parsing

Our `router` service emits logs in JSON format.

1. Open the [button label="Code"](tab-3) Instruqt tab
2. Navigate to `router/app.ts`
```
import { Logger } from "tslog";
const logger = new Logger({ name: "router", type: "json" });
```

Logs are emitted to stdout and written to disk by k8s. Let's have a look:

1. Open the [button label="Services Host"](tab-6) Instruqt tab
2. Enter the following `kubectl` command:
```bash,run
kubectl -n trading-1 get pods
```
3. Note the `router` pod name as <router-pod-name> (used in the next step)
4. Enter the following `kubectl` command:
```bash,run
kubectl -n trading-1 logs <router-pod-name>
```

Note that we are writing out logs in JSON format.

We are then using OTTL to parse out the fields in these JSON logs:

1. Open the [button label="OTel Operator YAML"](tab-5) Instruqt tab
2. Navigate to `apm/serverless.yaml`
3. Search for `transform/parse_json_body`

Note the OTTL used to parse the JSON.

Let's examine the results.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover` > `ES|QL`
3. Search for:
```
FROM logs-*
| WHERE service.name == "router"
```
4. Open a record to examine it

# Streams

## Partioning

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Streams`
3. Open the `logs` Wired stream
4. Select `Paritioning` tab
5. Click `Suggest paritions`
6. Click `Accept` for `logs.proxy`
7. Click `Create stream` in the `Confirm stream creation` dialog
8. Click `View in Discover`

## ES|QL Query-Time Parsing

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover` > `ES|QL`
3. Execute:
```
FROM logs.proxy
| GROK body.text "%{IPORHOST:client_ip} %{USER:ident} %{USER:auth} \\[%{HTTPDATE:timestamp}\\] \"%{WORD:http_method} %{NOTSPACE:request_path} HTTP/%{NUMBER:http_version}\" %{NUMBER:status_code} %{NUMBER:body_bytes_sent:int} %{NUMBER:request_duration:float} \"%{DATA:referrer}\" \"%{DATA:user_agent}\""
| WHERE status_code IS NOT NULL
| EVAL @timestamp = DATE_PARSE("dd/MMM/yyyy:HH:mm:ss Z", timestamp)
| STATS status_count = COUNT() BY status_code, minute = BUCKET(@timestamp, "1 min")
```
4. Click on the pencil icon in the upper-right of the graph
5. Drag `status_code` to `Breakdown` (if needed)
6. Drag `minute` to `Horizontal axis` (if needed)
7. Drag` `status_count` to `Vertical axis`
8. Click on the disk icon in the upper-right of the graph
9. Click `New` in the `Save Lens visualization` dialog
10. Click `Save and go to Dashboard`
11. Click `Save in the upper-right
12. Set `Title` to: `Proxy Status`

## Streams Index-Time Parsing

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Streams`
3. Open the `logs.proxy` Wired stream
4. Select `Processing` tab
5. Click `Suggest a pipeline`
6. Click `Accept`
7. Click `Save changes`
8. Click `Confirm changes` in the `Confirm changes` dialog
9. Click `View in Discover`
___


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
TS metrics-* | WHERE data_stream.dataset == "prometheusreceiver.otel"
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
> Ensure you are issuing questions against the `Observability Agent (Extended)`

1. Click the `AI Agent` button in the upper-right corner of the dashboard
2. Select `Observability Agent (Extended)`
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
7. Execute the following question:
```
can you create a case to capture this issue including a summary of this conversation?
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
TS metrics.trader
```
5. Click the search (magnifying glass) icon in the upper-right of the graph area and enter the following in the `Search metric` field:
```
shares_traded_per_customer
```
6. Click `Explore` in the upper-right corner of the `shares_traded_per_customer` graph
7. Edit and execute the ES|QL query (to properly name the vertical axis and breakdown by symbol):
```
TS metrics.trader
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
2. Set the `Data view` to `metrics.trader`
3. Find the field `share_price` and drag it to the `Vertical axis`
4. Find the field `symbol` and drag it to `Breakdown`
5. Find the field `@timestamp` and drag it to `Horizontal axis`
6. Set the visualization type to `Line`
7. Click `Save and return`
8. Click `Save` in the upper-right of the dashboard
9. Set `Title` to:
```
Trading Operations
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
5. In `Select data view`, select `metrics.trader`
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
7. Click `SUBMIT` 10 (or so) times

### Add our swim lane graph to our dashboard

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Dashboards` > `Trading Operation`
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
2. Navigate to `Dashboards` > `Trading Operation`
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

___


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
2. Navigate to `Dashboards` > `Profilingmetrics`

## How does this work?

1. Open the [button label="OTel Operator YAML"](tab-5) Instruqt tab
2. Navigate to `profiling/profiler.yaml`

Note the OTel Collector configuration with the `profiling` receiver and `profilingmetrics` connector.

___


Workflows
===

# Basic

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `hello_world` workflow
4. Run it
5. Walk through the execution steps

# Calling an external REST API

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `ip_geolocator` workflow
4. Run it
5. Walk through the execution steps

# Calling an external REST API w/ conditionals and retries

1. Open the [button label="Elastic"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `ip_geolocator_advanced` workflow
4. Run it
5. Walk through the execution steps
