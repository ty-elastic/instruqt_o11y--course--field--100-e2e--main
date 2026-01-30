---
slug: getting-to-know-the-environment
id: grj4ju3xkn0l
type: challenge
title: Getting to know the environment
notes:
- type: text
  contents: |-
    # Get Started with
    # Elastic Observability Logs Essentials

    In this hands-on workshop, we will experience how Elastic Observability Logs Essentials, powered by the Search AI Platform, turns logs into clear and actionable insights. We will start by getting familiar with the environment for a Kubernetes based eCommerce application and verifying that everything is running smoothly. When an unexpected outage occurs, an alert fires and the business health dashboard lights up. We will then use Elastic to determine the user impact, assess the scope of the issue, and pinpoint the root cause.

    In this workshop we will:
    - Investigate an alert and connect it to the operational and business context
    - Analyze logs to understand user impact and geographic scope of the incident
    - Identify and confirm the root cause using enriched log data and metadata

    By the end of the session, we will see how Elastic’s speed, context, and relevance help SRE and DevOps teams move from alert to resolution with confidence, reduce downtime, and strengthen operational resilience using Elastic Observability Logs Essentials.
tabs:
- id: rvvmnkjftuvo
  title: Kibana
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 8080
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
- id: etda0zwrpuxf
  title: Kibana - external
  type: service
  hostname: es3-api
  path: /app/dashboards#/list?_g=(filters:!(),refreshInterval:(pause:!f,value:30000),time:(from:now-30m,to:now))
  port: 8080
  new_window: true
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
- id: ihtlnxzxmrsj
  title: k3s
  type: terminal
  hostname: k3s
difficulty: ""
timelimit: 0
enhanced_loading: null
---
# Elastic Observability Logs Essentials Workshop

Welcome to the Elastic Observability Logs Essentials Workshop. This is our chance to dive hands-on into logs, alerts, and real-time troubleshooting. We will learn how to monitor, explore, and resolve issues faster using Elastic Observability powered by the Search AI Platform.

We’ll start by getting familiar with the environment behind the logs.

## Environment Overview

To analyze logs effectively, we need to understand what is generating them. In this section, we will explore the architecture of a sample eCommerce application running on Kubernetes.

We are looking at Elastic Observability Logs Essentials managing an eCommerce application deployed on Kubernetes. It has three tiers:
- A frontend served by NGINX
- A backend, also on NGINX
- A MySQL database

Refer to the diagram for a visual of how everything connects.

![logs_essentials_diagram.png](../assets/logs_essentials_diagram.png)

> [!NOTE]
> The Elastic Agent is deployed as a sidecar in each pod to collect logs.

We now have a clear picture of the application stack and how logs are collected. With this foundation in place, we are ready to explore logs with the context needed to make smart decisions.

## Business Health Dashboard

Let's  start by checking the overall health of the business using a dashboard that visualizes critical metrics.

1. Open the `Dashboards` page.
![Screenshot 2025-08-04 at 16.54.28.png](../assets/Screenshot%202025-08-04%20at%2016.54.28.png)
2. Select the `Business Health Dashboard`.
3. Feel free to explore the dashboard for trends, spikes, or anything that stands out.  The environment should look healthy right now.
![Screenshot 2025-08-07 at 17.52.03.png](../assets/Screenshot%202025-08-07%20at%2017.52.03.png)
The Business Health Dashboard connects operational signals to business outcomes. It helps us track metrics like geographic distribution of users, HTTP status codes, top web pages, and SQL performance, all derived from logs. This kind of visual insight lets us spot issues before they impact customers.

## Discover Logs

Next, we will confirm that MySQL logs are being ingested and check for any existing errors.

1. Navigate to `Discover`.
![Screenshot 2025-08-04 at 18.20.07.png](../assets/Screenshot%202025-08-04%20at%2018.20.07.png)
2. Click on `Try ES|QL` to switch to ES|QL mode, which allows us to perform queries using ES|QL syntax.
![Screenshot 2025-08-04 at 18.21.23.png](../assets/Screenshot%202025-08-04%20at%2018.21.23.png)
3.  Run this query (this query will show a breakdown of the count of each log level for logs from `/var/log/mysql/error.log`):
![Screenshot 2025-08-04 at 18.24.03.png](../assets/Screenshot%202025-08-04%20at%2018.24.03.png)
```sql
FROM logs-mysql.error-default
| WHERE log.file.path == "/var/log/mysql/error.log"
| STATS count = COUNT(*) BY log.level
```
4. Confirm that the results show no errors.
![Screenshot 2025-08-04 at 18.24.40.png](../assets/Screenshot%202025-08-04%20at%2018.24.40.png)
5. This query will be useful later in the workshop, so let's save it by clicking `Save`.
![Screenshot 2025-08-04 at 18.26.08.png](../assets/Screenshot%202025-08-04%20at%2018.26.08.png)
6. Give the Discover session a name of `MySQL Events Grouped by Log Level` and click `Save`.
```text
MySQL Events Grouped by Log Level
```
![Screenshot 2025-08-04 at 18.28.01.png](../assets/Screenshot%202025-08-04%20at%2018.28.01.png)
> [!NOTE]
> You can search over a different time range using the time range selector.
> ![Screenshot 2025-08-04 at 18.30.45.png](../assets/Screenshot%202025-08-04%20at%2018.30.45.png)

We confirmed that logs from MySQL are flowing correctly and that there are no current issues. Saving this ES|QL query allows you to revisit it anytime without having to rewrite it, making it easy to compare changes over time.

## Summary
We now have an understanding of the eCommerce application, verified that the environment is healthy, and saved an ES|QL query to be used later.
