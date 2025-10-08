---
slug: getting-started
id: izlqqkzxglpx
type: challenge
title: Getting Started
tabs:
- id: u2nmw20sfz6j
  title: Elasticsearch
  type: service
  hostname: kubernetes-vm
  path: /app/apm/service-map
  port: 30001
difficulty: basic
timelimit: 600
enhanced_loading: null
---
The advent of [OpenTelemetry](https://opentelemetry.io) has forever changed how we capture observability signals. While OTel initially focused on delivering traces and metrics, support for collection of logs is now stable and gaining adoption, particularly in Kubernetes environments.

In this lab, we will explore several models for using OpenTelemetry to collect and parse logs.

# Lab Architecture

In this lab, we will be working with an exemplary stock trading system, comprised of several services and their dependencies running in Kubernetes. We are using the OpenTelemetry Operator to automatically instrument all of our services.

Our trading system is comprised of:

* `proxy`: a nginx reverse proxy which proxies requests from the outside into the trading system
* `trader`: a python application that trades stocks on orders from customers
* `router`: a node.js application that routes committed trade records
* `recorder-java`: a Java application that records trades to a PostgreSQL database

Finally, we have `monkey`, a python application we use for testing our system that makes periodic, automated trade requests on behalf of fictional customers. `monkey` routes its requests through `proxy`.

# Elasticsearch

We will be working with a live Elasticsearch instance, displayed in the browser tab to the left. We are currently looking at Elastic's dynamically generated Service Map. It shows all of the services that comprise our system, and how they interact with one another.

> [!NOTE]
> You are welcome to explore each service and our APM solution by clicking on each service icon in the Service Map and selecting `Service Details`

When you are ready, let's pivot over to Discover where we can easily query and parse our logs.

1. Click `Discover` in the left-hand navigation pane
2. Click `Try ES|QL`

This workshop will leverage [ES|QL](https://www.elastic.co/docs/reference/query-languages/esql), Elastic's query-time language, to query our logs. Please refer to the following diagram to familiarize yourself with the ES|QL interface in Discover. You can enter your queries in the pane at the top of the Elasticsearch Discover. You can change the time window of your search using the Time Filter. To execute a search, click the Play/Refresh icon.

![1_discover.png](../assets/1_discover.png)

Let's execute a test query to search and parse logs associated with our `proxy` service:

```esql
FROM logs-proxy.otel-default
| GROK body.text "%{IPORHOST:client_ip} %{USER:ident} %{USER:auth} \\[%{HTTPDATE:timestamp}\\] \"%{WORD:http_method} %{NOTSPACE:request_path} HTTP/%{NUMBER:http_version}\" %{NUMBER:status_code} %{NUMBER:body_bytes_sent:int} %{NUMBER:duration:float} \"%{DATA:referrer}\" \"%{DATA:user_agent}\"" // parse access log
| WHERE status_code IS NOT NULL
| EVAL @timestamp = DATE_PARSE("dd/MMM/yyyy:HH:mm:ss Z", timestamp) // use embedded timestamp as record timestamp
| KEEP @timestamp, client_ip, http_method, request_path, status_code, user_agent
```

When you are ready, click the `Next` button to continue.
