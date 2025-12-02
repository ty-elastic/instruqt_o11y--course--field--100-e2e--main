---
slug: demo
id: zzp0nxfxmxry
type: challenge
title: Demo
tabs:
- id: xdbcqb6naygo
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
- id: mdp2y75l0s6c
  title: Elasticsearch (breakout)
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
  new_window: true
- id: 3o6dqpvmx3sb
  title: Trader
  type: service
  hostname: host-1
  path: /
  port: 8080
- id: ssyhxjku2bhz
  title: host-1
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
- id: swrcs8e6rna6
  title: kubernetes-vm
  type: terminal
  hostname: kubernetes-vm
  workdir: /workspace/workshop
difficulty: basic
timelimit: 43200
enhanced_loading: null
---
Demo