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
  port: 9000
- id: yxqjd199fxhh
  title: Elastic-Breakout
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 9000
  new_window: true
- id: aq8oaqxxd2nc
  title: Trader
  type: service
  hostname: k3s
  path: /
  port: 8081
- id: qr48xrusvahx
  title: eshost
  type: terminal
  hostname: es3-api
- id: oheg6ftlfcme
  title: k3shost
  type: terminal
  hostname: k3s
difficulty: basic
timelimit: 43200
enhanced_loading: null
---
