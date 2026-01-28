---
slug: rca
id: dhr6ejfxxe9m
type: challenge
title: RCA
tabs:
- id: 7rvfqfwl8e3n
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
- id: m5k7oulgvtic
  title: Elasticsearch (breakout)
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
  new_window: true
- id: fppailha47cn
  title: Trader
  type: service
  hostname: host-1
  path: /
  port: 8081
- id: yqqhoyxjdhf2
  title: host-1
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
- id: 8xmsu3uv9ecw
  title: kubernetes-vm
  type: terminal
  hostname: kubernetes-vm
  workdir: /workspace/workshop
- id: jh24letmrqst
  title: VSCode
  type: service
  hostname: host-1
  path: /
  port: 8080
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

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
