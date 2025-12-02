---
slug: demo
id: djf9hko1ubhc
type: challenge
title: Demo
tabs:
- id: 6isqyipw1hmd
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
- id: cqdigxbelhba
  title: Elasticsearch (breakout)
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
  new_window: true
- id: aq8oaqxxd2nc
  title: Trader
  type: service
  hostname: host-1
  path: /
  port: 8080
- id: ent1or6pgmot
  title: host-1
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
- id: uv4y5drik7sj
  title: kubernetes-vm
  type: terminal
  hostname: kubernetes-vm
  workdir: /workspace/workshop
difficulty: basic
timelimit: 43200
enhanced_loading: null
---
Demo