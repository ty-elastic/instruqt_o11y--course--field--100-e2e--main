---
slug: rca
id: djf9hko1ubhc
type: challenge
title: RCA
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
  port: 8081
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
- id: zzk3aplqxisv
  title: VSCode
  type: service
  hostname: host-1
  path: /
  port: 8080
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

# Setup
1. Open the [button label="VSCode"](tab-5) Instruqt tab
2. Open the configuration menu and select `View` > `Command Palette`
3. Search for:
```
ChatGPT: MCP Servers
```
4. Click `Add Server`
5. Set `Server Name` to:
```
elasticsearch
```
6. Set `Server Type` to:
```
Streamable HTTP
```
7. Set `URL` to:
```
http://kubernetes-vm:30001/api/agent_builder/mcp
```

