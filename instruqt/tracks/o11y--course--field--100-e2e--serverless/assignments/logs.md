
Logs
===

# SQL Commentor
Typically, database audit logs cannot easily be associated with traces. Using SQL Commentor, however, it becomes possible to follow a trace all the way from user interaction down to the database audit log.

[SQL Commentor](https://google.github.io/sqlcommenter/) is a library that can be used by Java applications making SQL calls (here, `recorder-java`). SQL Commentor will look for an active OpenTelemetry trace and append the appropriate `traceparent` header as a comment to the SQL query. Most SQL databases (including postgresql) will output the comment as part of the audit log!

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Applications` > `Service map`
3. Select `recorder-java`
4. Select transaction `POST /record`
5. Click on the `Logs` tab under `Trace sample`
6. Note the inclusion of logs from `postgresql`

## How does this work?

We are loading the `recorder-java` service with a custom build of the java SQL commentor library.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `recorder-java.yaml`

The SQL commentor library will automatically add `trace.id` (if its available on the current context) to SQL commands as a comment. We are then parsing that `trace.id` out of the comments and putting it into a first-class `trace.id` field.

1. Open the [button label="K8s YAML"](tab-4) Instruqt tab
2. Navigate to `postgres.yaml`

Note the `regex_parser` operator specific in the `io.opentelemetry.discovery.logs.postgresql/config` annotation.

# OTTL Parsing

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

# Streams

## Partioning

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Streams`
3. Open the `logs` Wired stream
4. Select `Paritioning` tab
5. Click `Suggest paritions`
6. Click `Accept` for all of the recognized partitions

## ES|QL Query Time Parsing

1. Open the [button label="Elasticsearch"](tab-0) tab
2. Navigate to `Discover` > `ES|QL`
3. Execute:
```
FROM logs.proxy
| GROK body.text "%{IPORHOST:client_ip} %{USER:ident} %{USER:auth} \\[%{HTTPDATE:timestamp}\\] \"%{WORD:http_method} %{NOTSPACE:request_path} HTTP/%{NUMBER:http_version}\" %{NUMBER:status_code} %{NUMBER:body_bytes_sent:int} %{NUMBER:request_duration:float} \"%{DATA:referrer}\" \"%{DATA:user_agent}\""
| WHERE status_code IS NOT NULL
| EVAL @timestamp = DATE_PARSE("dd/MMM/yyyy:HH:mm:ss Z", timestamp)
| STATS status_count = COUNT() BY status_code, minute = BUCKET(@timestamp, "1 min")
```
4. Click on the pencil icon in the upper-right of the graph
5. Drag `status_code` to `Breakdown`
6. Drag `minute` to `Horizontal axis`
7. Drag` `status_count` to `Vertical axis`
8. Click on the disk icon in the upper-right of the graph
9. Click `New` in the `Save Lens visualization` dialog
10. Click `Save and go to Dashboard`
11. Click `Save in the upper-right
12. Set `Title` to: `Proxy Status`

## Streams Parsing
