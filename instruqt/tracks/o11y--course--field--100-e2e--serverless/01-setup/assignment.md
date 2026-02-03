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
