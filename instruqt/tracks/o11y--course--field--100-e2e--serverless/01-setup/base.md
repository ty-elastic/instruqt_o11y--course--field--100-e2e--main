---
slug: setup
id: xmql1z1hdt2c
type: challenge
title: Setup
tabs:
- id: zvxdesnpamie
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
- id: od0txjt2rf8q
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
- id: 9falvisnya86
  title: Trader (NA)
  type: service
  hostname: k3s
  path: /
  port: 8082
- id: uxmg2e791nft
  title: Code
  type: code
  hostname: k3s
  path: /workspace/workshop/src
- id: egfjlbcitmki
  title: K8s YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/k8s/yaml
- id: 0hvtwlczt4y6
  title: OTel Operator YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/agents
- id: hdp9opgzqab3
  title: Services Host
  type: terminal
  hostname: k3s
- id: ajbo9kz0lxtx
  title: GitHub Issues
  type: website
  url: https://github.com/ty-elastic/instruqt_o11y--course--field--100-e2e--main/issues
  new_window: true
- id: mvodj4cdjhua
  title: Slides
  type: website
  url: https://docs.google.com/presentation/d/11lkZIvLNwWR8Tm6edCsPTIImypjKiylzwhOAa8527EM/edit?usp=drive_link
  new_window: true
- id: ppfqqvaqdevp
  title: Grafana
  type: service
  hostname: k3s
  path: /
  port: 3000
  new_window: true
- id: oae9yx2izef4
  title: ES Host
  type: terminal
  hostname: es3-api
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

All of the following technologies are enabled in this environment. As time allows, I will be adding additional scripts for demonstration of specific features (linked to this ToC). In the interim, please feel free to explore on your own. All of the features iterated below are enabled in this demo.

* Agentic RCA
  * [Alert Correlation, Agentic Root Cause Analysis, and HIL Remediation](section-agentic-rca)
* [Workflows](section-workflows)
* Synthetics
* OOTB OTel Dashboards
  * k8s
  * Hosts
  * [Postgresql](section-ootb-otel-dashboards-postgresql)
  * [MySQL](section-ootb-otel-dashboards-mysql)
* Logging
  * [OTTL Parsing](section-logging-ottl-parsing)
  * Receiver Creator Parsing
* [OTel Profiling](section-otel-profiling)
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
  * [SQL Commentor](section-tracing-sql-commentor)
  * eBPF Zero Instrumentation Go

Supporting slides (where available) can be found [here](https://docs.google.com/presentation/d/11lkZIvLNwWR8Tm6edCsPTIImypjKiylzwhOAa8527EM/edit?usp=drive_link) .

