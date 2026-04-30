---
slug: setup
id: xmql1z1hdt2c
type: challenge
title: Setup
tabs:
- id: zvxdesnpamie
  title: Elastic
  type: website
  url: https://kibana.es3-api.${_SANDBOX_ID}.instruqt.io:60088/app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  new_window: false
- id: od0txjt2rf8q
  title: Elastic-Breakout
  type: website
  url: https://kibana.es3-api.${_SANDBOX_ID}.instruqt.io:60088/app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  new_window: true
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

