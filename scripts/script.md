# Setup
```
kubectl -n trading-1 port-forward service/proxy-ext 9091:8081 
kubectl -n trading-1 port-forward --address 0.0.0.0 deployment/router 9000:9000
```


# Metrics Demo Script

1) Explain architecture (microservices, mix of OTel and Prometheus)
2) Added prometheus metrics to router applications

------------------------------------------------------------------------------

# STEP1: Parity between Grafana UX and Kibana UX (Tablestakes for conversion)

Goal: convert Prom/Grafana customers to paid Elasticsearch customers

## Drill down

1) Grafana
- Drilldown, Metrics
- Quick search metrics: shares_traded
- Breakdown by region

2) Kibana (9.2)
- ESQL: `TS metrics-*`
- Quick search metrics: shares_traded
- Breakdown by region

## PromQL

1) Grafana
- Explore
- promql: `sum by (region) (rate(shares_traded[5m]))`
- Add to dashboard

2) Kibana (Serverless)
- PROMQL: `PROMQL index=metrics-* start=?_tstart end=?_tend step=5m sum by (region) (rate(shares_traded[5m]))`
- copy to dashboard

## Summary
- just the start
- native PROM storage 
- native PROMQL query from Grafana




------------------------------------------------------------------------------

# STEP2: Best in Class OTel Metrics (new customers, eventual migration for prom customers)

What's so great about OTel Metrics?
- common attributes across metrics, logs, and traces
- standardized schema (prom doesn't define a schema)

## OOTB Dashboards

We are working to improve the OOTB dashboard experience. Expect new k8s, hosts, and other core dashboard experiences coming soon.

1) Kibana (Serverless)
- Dashboards
- [OTEL]Metrics Kubernetes] Cluster Overview

2) VSCode
- Show postgresqlreceiver sidecar to postgresql

3) Kibana (Serverless)
- Integrations
- Search for postgres
- Install
- Dashboards
- [Metrics PostreSQL OTel] Database Overview

## Full-Fidelity Metric Support in ES|QL

Filling in comprehensive metrics support in ESQL

1) Kibana (Serverless)
- Histograms:
```
TS metrics-* | WHERE http.client.request.duration IS NOT NULL | KEEP http.client.request.duration
```

```
TS metrics-* | WHERE http.client.request.duration IS NOT NULL | EVAL duration = TO_TDIGEST(http.client.request.duration) | STATS AVG(duration), MAX(duration), MIN(duration)
```
- Rates
```
TS metrics-* | WHERE event.dataset == "prometheusreceiver.otel" | WHERE shares_traded IS NOT NULL | STATS st = MAX(LAST_OVER_TIME(shares_traded)) BY region, TBUCKET(5m)
```

```
TS metrics-* | WHERE event.dataset == "prometheusreceiver.otel" | STATS shares_traded_delta = SUM(rate(shares_traded)) BY region, BUCKET(@timestamp, 5m)
```

## Analytics

1) Kibana (Serverless)
- Machine Learning
- SLOs


------------------------------------------------------------------------------


# STEP3: AI-Centric Metric Workflows

Metrics provide alerts and correlated evidence to RCA

## Dynamic Dashboards

1) Kibana (9.4)
- AgentBuilder (Dashboards)
```
I have a nodejs express app which routes trading requests via REST. it stores metrics in the `metrics-router` index. can you generate a dashboard which visualizes the top 2 things I should pay attention to when monitoring this service?
```

## Agent-Based RCA Conversation

Building custom tools can really help sharpen AI response

1) Kibana (Serverless)
- AgentBuilder (Observability Agent)
```
using the `shares_traded` counter, can you identify when trading stopped in the `EU` region?
```

```
when trading stopped, were there any logs in any of the services that might indicate what is happening?
```

## Fully Agentic RCA

1) Kibana (Serverless)
- Alerts
- Cases
- RCA

## MCP

1) Kibana (Serverless)
- show custom tools

2) VSCode
- router/app.ts
- highlight `shares_traded` metric
- Add Selection to Chat
```
i send this prom metric to elasticsearch. what are the values over the past 15 minutes?
```

```
can you break this down by symbol instead?
```

------------------------------------------------------------------------------