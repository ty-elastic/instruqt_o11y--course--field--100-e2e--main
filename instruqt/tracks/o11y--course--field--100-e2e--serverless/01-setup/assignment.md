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
- id: qr48xrusvahx
  title: eshost
  type: terminal
  hostname: es3-api
- id: oheg6ftlfcme
  title: k3shost
  type: terminal
  hostname: k3s
- id: s1uqc0oc3nlk
  title: Grafana
  type: service
  hostname: k3s
  path: /
  port: 3000
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

Agentic RCA
===

# Goals
* Show fully agentic alert correlation and multi-signal RCA w/ context.

# Technical Setup
Before the demo, complete `Steady-State` and `Generate Alerts`.

## Steady-State

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Alerts`
3. Refresh until there are no active alerts (leftover from startup)
4. Navigate to `Workflows`
5. Enable workflow `alert_queue`

## Generate Alerts

1. Open the [button label="Trader"](tab-2) Instruqt tab
2. Navigate to `ERROR`
3. Open `DB`, select `Generate errors`, select region `EU`, and click `SUBMIT`

# Audience Setup

* We have a set of microservices which implement a financial trading application
* Our database imlements SQL data contraints which validate certain parameters, including that the number of shares being traded is a positive value
* We are going to intentionally introduce errors into the system whereby all of the trades coming from the EU region are trying to trade a negative number of shares

Let's first debug this problem manually:

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Observability` > `Applications` > `Service map`
3. Note the dependency chain leading back from `postgresql`. Database validation errors will propagate backwards through `recorder-java`, `router`, and `trader`
4. Click on the `trader` service
5. Click on `Service Details`
6. Scroll down to `Transactions` and select `POST /trade/request`
7. Search for
```
status.code :"Error"
```
8. Scroll down to the waterfall graph and note the rippling error from database `INSERT` back up through the `Trader` application
9. Click `View related error` on the failed `INSERT trades.trades` span
10. Click on the error message `ERROR: new row for relation "trades" violates check constraint "trades_share_price_check"`

So we've now confirmed that our induced database error is indeed causing some number of related errors.






## Monitoring

After some time, multiple failure alerts will fire.

1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Observability` > `Alerts`
3. Note the 3 releated failure alerts

As these alerts fire, workflows are automatically triggered


2. Navigate to `Workflows`
3. Note that `alert_queue` will trigger, then `alert_dequeue`, then `alert_process`, then `case_dequeue`, then `case_process`. You can `alert_process` and `case_process` to follow along.

# Outcome
1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Cases`
3. Eventually you should have a new Case created with all 3 alerts correlated and attached, followed by a Root Cause analysis

# Remediation
1. Open the [button label="Elasticsearch"](tab-0) Instruqt tab
2. Navigate to `Cases`
3. Open the created Case
4. Follow the link at the bottom to `continue the investigation`
5. In the AI Assistant, enter the following `can you restart the proxy service?`
6. Wait for confirmation that the process has been restarted
7. Navigate to `Workflows`
8. Open the `remediation_restart_service` workflow, click `Executions`, and follow along with the last execution
9. Open the [button label="host-1"](tab-3) Instruqt tab
10. Enter the following on the command line
```bash,run
kubectl -n trading-1 get pods
```
11. Note that the `proxy` pod has been recently restarted!
