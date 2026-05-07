
## SETUP

### Alerts

3) Alert > Rules > [Elastic Agent] Unhealthy status > Related dashboards => Concerning agents
4) Alert > Rules > [Elastic Agent] Unhealthy status > Enable

### Streams

0) SigEvents uses Opus
1) Spark > SigEvents
2) generate significant events
3) add rules

### Database

1) Generate errors
2) run alert process

### Infra

1) setup ML
2) create alert (individual, level=10)

### APM

1) setup ML

# --------------------------
# Use Case 3: Data Collection Health, Configuration Management, and Fleet/Agent Lifecycle

## DEMO

### Linux monitoring
1) Infrastructure > Hosts
2) es3-api

### Agent upgrade
1) Fleet > es3-api > Upgrade agent

### Onboarding windows
1) Fleet > Add > Agent
2) Create new agent policy
3) Windows Server
4) Create policy

5) Install Elastic Agent
6) Windows x86_64

7) Windows VM
8) Start menu > Powershell > run as admin
9) Fleet > copy
10) Windows VM > paste

11) Elastic confirm data

12) Infrastructure > Hosts
13) windows

### Integrations
1) Fleet > Agent policies
2) Windows Server
3) Add integration
4) IIS
5) Syslog > tcp port 9514, udp port 9514
```
- if:
    and:
      - not.has_fields: _conf.dataset
      - regexp.message: 'hpc-'
  then:
    - add_fields:
        target: ''
        fields:
          _conf.dataset: "hpc"
    - syslog:
        field: message
        format: rfc5424
```

### See environment

1) Fleet > Ingest Overview Metrics
2) Discover > logs-*
3) AI Agent
```can you graph logs per second by org?```

### Error
1) Set Syslog > tcp port 445
2) agent goes unhealthy
3) Fleet
4) Agents > windows
5) syslog-router-1: needs attention > inputs tcp
6) alerts
7) details
8) help me understand
9) AI conversation
10) `do we have a convention for syslog port?`

### Fix
1) Fleet
2) Agent policies > Windows Server

# --------------------------
# Use Case 2: AI-Assisted Data Onboarding, Normalization, and Time-to-Insight Acceleration

## Onboarding

1) Streams
2) logs coming into logs.otel
3) partitioning
4) proxy logs are messy
5) auto pipeline
6) parsed
7) set lifecycle

## Immediate value?

1) can you generate ESQL to breakdown http status code over time?
2) add to dashboard
3) lens (graph request time)
4) can you graph http response size over time?

## Streams
1) Spark
2) Knowledge Indicators
3) Rules

# --------------------------
# Use Case 1: Native AI-Assisted Exploration, Question Answering, and Dashboard Creation

## HPC
1) streams > HPC logs
2) discover
3) can you graph individual fan speed over time? ignore ****
4) can you create a dashboard with this graph as well as another graph graphing temperature over time?
5) AI agent: does fan speed affect temp?

## DB Dashboard

1) postgresql rollbacks
2) switch to RCA agent
4) what caused the spike in rollbacks?
5) is this a known issue?
6) can you open a case on this?

# --------------------------
# Use Case 4: Dynamic, State-Aware Alerting with Automated Incident Lifecycle Management

create high mem:

1) stress --vm 1 --vm-bytes 2048M --timeout 300s
2) wait for anomaly detection and alert
3) RCA happens automatically
4) clear condition, case closes


2) RCA
- alert correlation
- alert dedup
- remediate
- elastic-ramen
- can you use the CLI to list pods running in this namespace?
- can you add this table to the list?

# --------------------------
# Use Case 6: AI-Assisted Health Monitoring of the Observability Platform Itself
1) streams
2) AI:
```
what is causing the degraded quality of this data stream?
```

## Hosted Monitoring
1) why is my cluster health yellow?

## AutoOps
2) slow query