---
slug: agentsworkflows
id: cce3tbymjnsc
type: challenge
title: Agents & Workflows
tabs:
- id: udgjapje19s2
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
- id: ycm2gzaeeumb
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
- id: ux1gyn9va8x3
  title: Trader (NA)
  type: service
  hostname: k3s
  path: /
  port: 8082
- id: 2qhk2m4kxo60
  title: Code
  type: code
  hostname: k3s
  path: /workspace/workshop/src
- id: 4jr18rzknrmq
  title: K8s YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/k8s/yaml
- id: to9gtiqjbfqj
  title: OTel Operator YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/agents
- id: qzziqwyh6duo
  title: Services Host
  type: terminal
  hostname: k3s
- id: mkpbttxyvsmq
  title: GitHub Issues
  type: website
  url: https://github.com/ty-elastic/instruqt_o11y--course--field--100-e2e--main/issues
  new_window: true
- id: wkukufxgilvu
  title: Slides
  type: website
  url: https://docs.google.com/presentation/d/11lkZIvLNwWR8Tm6edCsPTIImypjKiylzwhOAa8527EM/edit?usp=drive_link
  new_window: true
- id: y4wlbkmx0agr
  title: Grafana
  type: service
  hostname: k3s
  path: /
  port: 3000
  new_window: true
- id: fw7964ipiesi
  title: ES Host
  type: terminal
  hostname: es3-api
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

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
