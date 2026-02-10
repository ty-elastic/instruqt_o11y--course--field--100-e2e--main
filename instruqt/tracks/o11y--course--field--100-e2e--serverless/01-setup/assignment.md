---
slug: setup
id: jzt084dwebvp
type: challenge
title: Setup
tabs:
- id: apziqi98f6vo
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
- id: yxqjd199fxhh
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
- id: ip5dkifrpofc
  title: Trader
  type: service
  hostname: k3s
  path: /
  port: 8081
- id: acj1llndlxop
  title: Code
  type: code
  hostname: k3s
  path: /workspace/workshop/src
- id: fqewbjcpqcys
  title: K8s YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/k8s/yaml
- id: ded3xt94i2f7
  title: OTel Operator YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/agents
- id: oheg6ftlfcme
  title: Services Host
  type: terminal
  hostname: k3s
- id: csyzrgrkku19
  title: GitHub Issues
  type: website
  url: https://github.com/ty-elastic/instruqt_o11y--course--field--100-e2e--main/issues
  new_window: true
- id: s1uqc0oc3nlk
  title: Grafana
  type: service
  hostname: k3s
  path: /
  port: 3000
  new_window: true
- id: qr48xrusvahx
  title: ES Host
  type: terminal
  hostname: es3-api
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

Technology Highlights:
* Agentic RCA
  * [Alert Correlation, Agentic Root Cause Analysis, and HIL Remediation](section-agentic-rca)
* Workflows
* Synthetics
* OOTB OTel Dashboards
  * k8s
  * Hosts
  * Postgresql
* OTel Logging
  * OTTL Parsing
  * Receiver Creator Parsing
* Profiling
  * OTel Profiling
* Streams
  * Wired
    * Partitioning
    * Parsing
    * Significant Events
* Metrics
  * OTel Metrics
  * Metrics w/ ES|QL
  * Prometheus Metrics
  * PROMQL
* Tracing
  * Custom Attributes
  * Baggage
  * OTel-based RUM
  * SQL Commentor
  * eBPF Zero Instrumentation Go

Agentic RCA
===

# Alert Correlation, Agentic Root Cause Analysis, and HIL Remediation

## Goals
* Show fully agentic alert correlation and multi-signal RCA with context

## Technical Setup

Perform these steps before you start the demo.

### Steady-State

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Alerts`
3. Wait until there are no active alerts (service startup will trigger some failure alerts)

### Generate Alerts

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `ERROR`
3. Open `DB`, select `Generate errors`, select region `EU`, and click `SUBMIT`
4. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
5. Navigate to `Alerts`
6. Wait for new alerts to appear

## Demo

### Introduction

We have a set of microservices which implement a financial trading application:
1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`

Our database imlements SQL data contraints which validate certain parameters, including that the number of shares being traded is a positive value:
1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgresql.yaml`
3. Note that `CREATE TABLE` (line 78) assigns constraints to specific fields

We are intentionally introducing errors into the system whereby all of the trades coming from the `EU` region will be trying to trade a negative number of shares and violate the database constraints.

### Manually Debug

Let's first debug this problem with minimal AI assistant as an SRE might do today:

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
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

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Applications` > `Service map`
3. Note the dependency chain leading back from `postgresql`. Database validation errors will propagate backwards through `recorder-java`, `router`, and `trader`.

### Automated Alert Correlation

Let's see how we can leverage OneWorkflow, Agent Builder, and Cases to correlate related alerts together.

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `alert_process` workflow
4. Manually execute it

Normally, Elasticsearch would trigger this workflow automatically from an alert rule, but here we are intentionally executing it manually so we can observe its progress.

#### (Optional) Workflow Walkthrough

If the customer is interested in understanding OneWorkflow, you can optionally walk them through the execution steps. I would generally note here that we are working to bring alert correlation into the platform.

5. The workflow starts executing
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

#### View correlation results

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Cases`
3. Open the newly created case
4. Click `Attachments` and note that all 3 related alerts were correlated to the same case
5. Click `Activity` and note that when each alert was added, a comment was automated appended indicating a summary of the alert and why it was correlated to this case
6. Click on the `Conversation` link in the comment for an added alert
7. In the AgentBuilder conversation, click on `Completed reasoning` to see all of the steps the agent took to correlate this alert to this case (you can further investigate tool calls if you'd like)

### Automated Root Cause Analysis

Let's see how we can leverage OneWorkflow, Agent Builder, and Cases to perform agentic Root Cause Analysis.

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Workflows`
3. Open the `case_process` workflow
4. Manually execute it

Normally, this workflow would be triggered automatically, but here we are intentionally manually executing it so we can observe its progress.

#### (Optional) Workflow Walkthrough

If the customer is interested in understanding OneWorkflow, you can optionally walk them through the execution steps. I would generally note here that we are working to bring agentic RCA into the platform.

5. The workflow starts executing
6. Open `is_workflow_running` > `false` > `foreach_case` > `0` > `is_case_unstable` > `false` > `if_needs_update` > `true` > `rca`
7. Click on `Input` and note that we are passing the case to the `rca` Agent (`body`)
8. Click on `Output` and note that we are getting back the root cause analysis (`response.message`)
9. Open `is_workflow_running` > `false` > `foreach_case` > `0` > `is_case_unstable` > `false` > `if_needs_update` > `true` > `add_response_to_existing_case`
10. Click on `Input` and note that we are appending the root cause analysis to the case (`body.comment`)

In the next step, we will have the opportunity to see the reasoning steps the Agent took to perform the root cause analysis.

#### View RCA results

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
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

1. Starting from the last step, at the bottom of the case, you will find a link to continue investigation or take remedial action
2. Enter the following into the `Ask anything` box at the bottom of the Agent
```
was there a spike in log rate when this issue started occurring?
```
3. Enter the following into the `Ask anything` box at the bottom of the Agent
```
can you update the case with the results of our log rate analysis?
```

After the agent is done, let's verify that the case was updated:
1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Observability` > `Cases`
3. Open the case
4. Scroll down to the last comments in the case and note that it now includes our log rate analysis

### Remediation

We intentionally make remediation a Human-In-the-Loop (HIL) activity, though of course we could have told our agent to automatically take this step if we wanted. You'll recall that the RCA analysis suggested we could remediate the issue by restarting the `monkey` service. Let's do it!

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
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
kubectl -n trading-1 get pods
```
3. Note that the `monkey` pod was recently restarted

#### (Optional) How does this work?

Remediation can be achieved by teaching the RCA Agent how to call a Workflow that in turn can call a remote command.

Let's have a look at the RCA Agent:
1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Agents` (it may be hidden under the `...` menu)
3. Click on `More` in the upper-right and select `View all tools`
4. Enter the following into the search bar
```
remediation
```
5. Click on the `remediation_service_action` tool and note that it calls the `remediation_service_action` workflow

Let's have a look at the `remediation_service_action` workflow:
1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
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

