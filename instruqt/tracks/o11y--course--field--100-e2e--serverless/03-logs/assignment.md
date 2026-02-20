---
slug: logs
id: a6oz90ftwzwx
type: challenge
title: Logs
tabs:
- id: d1rftgpbu69m
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
- id: 9dwnt4zm84pk
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
- id: ectt6cpzlopp
  title: Trader (NA)
  type: service
  hostname: k3s
  path: /
  port: 8082
- id: z8aihn4x5uck
  title: Code
  type: code
  hostname: k3s
  path: /workspace/workshop/src
- id: jkyb32dmruhs
  title: K8s YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/k8s/yaml
- id: 9wp0tvj89x5s
  title: OTel Operator YAML
  type: code
  hostname: k3s
  path: /workspace/workshop/agents
- id: jongcxodr9h2
  title: Services Host
  type: terminal
  hostname: k3s
- id: peb9umbhw9jm
  title: GitHub Issues
  type: website
  url: https://github.com/ty-elastic/instruqt_o11y--course--field--100-e2e--main/issues
  new_window: true
- id: qqxjes3dwbyl
  title: Slides
  type: website
  url: https://docs.google.com/presentation/d/11lkZIvLNwWR8Tm6edCsPTIImypjKiylzwhOAa8527EM/edit?usp=drive_link
  new_window: true
- id: vm29hokb43hd
  title: Grafana
  type: service
  hostname: k3s
  path: /
  port: 3000
  new_window: true
- id: agxqla1qotah
  title: ES Host
  type: terminal
  hostname: es3-api
difficulty: basic
timelimit: 43200
enhanced_loading: null
---

SQL Commentor
===

Typically, database audit logs cannot easily be associated with traces. Using SQL Commentor, however, it becomes possible to follow a trace all the way from user interaction down to the database audit log.

[SQL Commentor](https://google.github.io/sqlcommenter/) is a library that can be used by Java applications making SQL calls (here, `recorder-java`). SQL Commentor will look for an active OpenTelemetry trace and append the appropriate `traceparent` header as a comment to the SQL query. Most SQL databases (including postgresql) will output the comment as part of the audit log!

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Applications` > `Service map`
3. Select `recorder-java`
4. Select transaction `POST /record`
5. Click on the `Logs` tab under `Trace sample`
6. Note the inclusion of logs from `postgresql`

# How does this work?

We are loading the `recorder-java` service with a custom build of the java SQL commentor library.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `recorder-java.yaml`

The SQL commentor library will automatically add `trace.id` (if its available on the current context) to SQL commands as a comment. We are then parsing that `trace.id` out of the comments and putting it into a first-class `trace.id` field.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgres.yaml`

Note the `regex_parser` operator specific in the `io.opentelemetry.discovery.logs.postgresql/config` annotation.

OTTL Parsing
===

Our `router` service emits logs in JSON format.

1. Open the [button label="Code"](tab-3) Instruqt tab
2. Navigate to `router/app.ts`
```
import { Logger } from "tslog";
const logger = new Logger({ name: "router", type: "json" });
```

Logs are emitted to stdout and written to disk by k8s. Let's have a look:

1. Open the [button label="Services Host"](tab-6) Instruqt tab
2. Enter the following `kubectl` command:
```bash,run
kubectl -n trading-1 get pods
```
3. Note the `router` pod name as <router-pod-name> (used in the next step)
4. Enter the following `kubectl` command:
```bash,run
kubectl -n trading-1 logs <router-pod-name>
```

Note that we are writing out logs in JSON format.

We are then using OTTL to parse out the fields in these JSON logs:

1. Open the [button label="OTel Operator YAML"](tab-5) Instruqt tab
2. Navigate to `apm/serverless.yaml`
3. Search for `transform/parse_json_body`

Note the OTTL used to parse the JSON.

Let's examine the results.

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover` > `ES|QL`
3. Search for:
```
FROM logs-*
| WHERE service.name == "router"
```
4. Open a record to examine it
