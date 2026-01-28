---
slug: mcp
id: xf7adpjt1sd2
type: challenge
title: MCP
tabs:
- id: lvudbbn0xojl
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
- id: lmsjzmbn3ddp
  title: Elasticsearch (breakout)
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
  new_window: true
- id: kojvl2izcn95
  title: Trader
  type: service
  hostname: host-1
  path: /
  port: 8081
- id: 6j4kfnxtykpo
  title: host-1
  type: terminal
  hostname: host-1
  workdir: /workspace/workshop
- id: kmnzm5poqvtt
  title: kubernetes-vm
  type: terminal
  hostname: kubernetes-vm
  workdir: /workspace/workshop
- id: wygirmylndyu
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

