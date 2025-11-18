# Proposed Bradesco Demo Flow

# Accounts

## SNOW
* user: `admin`
* password: `Ni8nfQDG*8e@`

## WinArm64

* user: `windowsadmin`
* password: `4vQA@.Q9tZa2Fk9`

# Reset

* remove Notifier service from SNOW
* remove streams /logs IIS partition
* remove redact ingest pipeline
* clear alerts
* remove old case
* remove old alert rules
* remove tags from old dashboards
* remove old ML jobs
* remove dashboards from trader
* remove saved objects from other cluster

# Checklist

* SNOW cluster is up
* WindArm64 is up and accessible
* Trader app is up
* Kesta is up

# Section 2

## Onboarding Telemetry

### Onboarding a new host (Windows ARM)

#### Script

1) Show Collector Config on Windows ARM
2) Start Collector on Windows
3) Show logs coming into Wired Streams
4) Partition logs with Streams AI

5) Parse logs with Streams AI
- `body.structured.message`

--- REMEMBER TO START SIG EVENTS

6) In Discover, make graph of http status codes
```
FROM logs.iis-*
| WHERE http.response.status_code >= 400
| STATS status = COUNT() BY BUCKET(@timestamp, 5s)
```
7) add graph to dashboard
8) create alert

9) use AI Assistant to query:
```
can you graph a count of failed http status codes from my IIS logs over the last hour?
```
10) could add graph to dashboard

11) Setup significant events with Streams AI for IIS
* first needs to recognize the log type
* generate sig events

#### Objectives

* 2.5
    * Support for Windows operating system (ARM architecture) to collect OS metrics and identify technologies running on the host

* 6.19
    * Ability to configure alerts directly from dashboards

* 10.6
    * Allow threshold changes using natural language.

* 10.7
    * Enable the creation of dashboards using natural language.

## Interacting with Data

### Working with Log Data

#### Script

1) Show logs in Discover (`logs`)
2) Show log lines around the line I'm looking at
3) Use AI Assistant to look for neighboring logs

4) Log patterns
5) Go to APM and view logs for a trace 
6) Note email address in log (`trader`)
7) Create ingest pipeline with REDACT processor
- Processor=Redact
- Field=`body.text`
- Patterns = `%{EMAILADDRESS:REDACTED}`
- ignore missing
- ignore failures
8) Show email address is now redacted

#### Objectives

* 3.13
    * Support for masking sensitive data

* 4.10
    * Allow the visualization of neighboring logs

### Working with Metrics

#### Script

1) show otel metrics from linux kubernetes hosts in hosts UX
2) add graph to my dashboard
3) show ML for memory usage with forecasting
4) add Lens for `com.example.share_price` over time, split by `attributes.com.example.symbol`
5) detect anomalies
6) view results (`share_price`)

#### Objectives

* 6.28
    * Support for preformatted visualization with key metrics based on OpenTelemetry, using data from OpenTelemetry collectors

* 7.17
  * Problem and incident prediction


### Working with Alerts

#### Script

1) go to hosts ux
2) alerts -> create inventory rule
3) add warning threshold
4) add snow (short description)
5) show active alerts, group by tags
6) we are doing maintenance, so setup maintenance window

#### Objectives

* 10.6
    * Allow threshold changes using natural language.

* 7.5
    * Integration with ServiceNow for alert delivery

* 7.3
    * Definition of dynamic thresholds (baseline-based)

* 7.14
    * Alert management by severity and priority

* 7.6
    * Allow alert suppression per period (maintenance window) per service

### Working with Dashboards

#### Notes

* export a dashboard that can be shown on another system

#### Scripts

1) Show Dashboard Access
2) Run Workflow to tag old dashboards
3) Delete old dashboards
4) Export dashboard `Workflow Monitoring` from one cluster, import to another

- Management > Saved Objects > Export
- Switch Cluster > Import

5) via curl

```
curl -X POST "https://bradesco-61ec7f.kb.us-west2.gcp.elastic-cloud.com/api/saved_objects/_export" \
  -H "kbn-xsrf: true" \
  -H "Authorization: ApiKey WnV1MGJwb0JoVjl5eHE3Nlhqc0s6aG82a0NId1VqS09WNXBlUzZrRVBLdw==" \
  -H "Content-Type: application/json" \
  -d '{
        "objects": [
          {
            "id": "d97430db-e4f8-450e-be83-8a173d60ed9f",
            "type": "search"
          }
        ],
        "includeReferencesDeep": true
      }' \
  -o exported_objects.ndjson
```

```
curl -X POST "https://bradesco2-21a62d.kb.us-west2.gcp.elastic-cloud.com/api/saved_objects/_import?overwrite=true" \
-H "kbn-xsrf: true" \
-H "Authorization: ApiKey b2l2bGtwb0JJVG5WOUVwMk50UVE6TGo4MXVYMGQ0ckVqOWY1T3R1b3NRUQ==" \
--form file=@exported_objects.ndjson
```

#### Objectives

* 6.10
    * Enable tracking the usage (access/popularity) of dashboards

* 6.11
    * Allow decommissioning dashboards that have not been used for a certain period

* 6.29
    * Migration of dashboards between different tenants/instances

# Section 4

## Workflow

### Basics

#### Script

1) create basic workflow

```
version: "1"
name: test_workflow
enabled: true
triggers:
  - type: manual
inputs:
  - name: user_name
    type: string
steps:
  - name: first-step
    type: console
    with:
      message: Hello {{ inputs.user_name }}
  - name: get_www
    type: http
    with:
      url: https://elastic.co
      method: GET
      headers: {}
    timeout: 5s
    on-failure:
      fallback:
        - name: debug
          type: console
          with:
            message: http call failed
  - name: store_www
    type: elasticsearch.request
    with:
      method: POST
      path: "test_index/_doc"
      body:
        content: "{{ steps.get_www.output.data }}"
```

5) triggers: schedule workflow to run
6) triggers: connect to alert based on metric threshold - connect to alert we setup before

#### Objectives

* 8.10
  * Oferecer bibliotecas de ações predefinidas
  * Provide libraries of predefined actions

* 8.25
  * Suporte para uso de variáveis e templates em automações
  * Support for the use of variables and templates in automations

* 8.22
  * Possuir mecanismos de retry e fallback
  * Support for retry and fallback mechanisms

* 8.5
  * Permitir o agendamento de automações
  * Enable automation scheduling

* 8.12
  * Permitir orquestrar ações com base em métricas específicas
  * Allow orchestrating actions based on specific metrics

* 8.4
  * Suportar chamada de APIs como automação em resposta a alertas
  * Support API calls as automation in response to alerts

### Management

#### Script

1) show up/down of workflows using API (devops)

```
curl -H "Authorization: ApiKey WnV1MGJwb0JoVjl5eHE3Nlhqc0s6aG82a0NId1VqS09WNXBlUzZrRVBLdw==" -H "kbn-xsrf: true" -H "x-elastic-internal-origin: Kibana" https://bradesco-61ec7f.kb.us-west2.gcp.elastic-cloud.com/api/workflows/workflow-e5b49dc0-3443-4df3-8700-d2fc744ca952 > workflow.json
```

(modify)

```
curl -H "Authorization: ApiKey WnV1MGJwb0JoVjl5eHE3Nlhqc0s6aG82a0NId1VqS09WNXBlUzZrRVBLdw==" -H "kbn-xsrf: true" -H "x-elastic-internal-origin: Kibana" -H "Content-Type: application/json" -X PUT -d @workflow.json https://bradesco-61ec7f.kb.us-west2.gcp.elastic-cloud.com/api/workflows/workflow-e5b49dc0-3443-4df3-8700-d2fc744ca952
```

2) show workflows called from curl for testing (devops)

```
curl -H "Authorization: ApiKey WnV1MGJwb0JoVjl5eHE3Nlhqc0s6aG82a0NId1VqS09WNXBlUzZrRVBLdw==" -H "kbn-xsrf: true" -H "x-elastic-internal-origin: Kibana" -H "Content-Type: application/json" -X POST -d '{"inputs":{"user_name":"bob"}}' https://bradesco-61ec7f.kb.us-west2.gcp.elastic-cloud.com/api/workflows/workflow-e5b49dc0-3443-4df3-8700-d2fc744ca952/run
```

3) show SLOs
4) define alert for workflow
5) show dashboard
6) show user without access to workflows index RBAC

#### Objectives

* 8.11
  * Versionamento de playbooks e rollback automático
  * Playbook versioning and automatic rollback

* 8.24
  * Permitir testes automatizados dos playbooks
  * Allow automated testing of playbooks

* 8.6
  * Painel de automações
  * Automation dashboard

* 8.23
  * Possibilidade de configurar SLAs para execução das automações
  * Ability to configure SLAs for automation execution

* 8.17
  * Enviar notificações sobre o sucesso ou falha da automação
  * Send notifications on automation success or failure

* 8.15
  * Controle de acesso por papel (RBAC) para execução de automações
  * Role-based access control (RBAC) for automation execution

### Integration

#### Script

1) run the workflow `test_webhook_TO_github`

#### Objectives

* 8.4
  * Suportar chamada de APIs como automação em resposta a alertas
  * Support API calls as automation in response to alerts

* 8.29
  * Interagir com scripts externos armazenados em repositórios Git
  * Interact with external scripts stored in Git repositories

## Automated Incident Response

### Toplogy Building

1) Show ServiceMap
2) Show SNOW lacking notifier service

3) show github action calling workflow
- add file to main
- updates topology

4) Fill in SNOW Services
5) add details to trader

### Objectives 

* 7.16
    * Integração com sistemas de gerenciamento de configuração (CMDB)
    * Integration with configuration management systems (CMDB)

* 8.29
  * Interagir com scripts externos armazenados em repositórios Git
  * Interact with external scripts stored in Git repositories

### Handling Many Alerts

#### Script

1) trigger problem with database service
2) show failure correlation to see what's really happened
2) multiple alerts
3) correlation workflow triggers
4) one incident with attached alerts
5) cmdb enrichment
6) automated RCA, noting existing issue and toplogy

#### Objectives

* 7.7
  * Capacidade de enriquecimento dos dados do alerta
  * Ability to enrich alert data

* 7.18
  * Automatização de respostas a incidentes
  * Automation of incident response

* 10.8
  * Análise de impacto (blast radius) usando IA
  * Impact analysis (blast radius) using AI

* 8.27
  * Ter suporte para aprendizado contínuo com base nos incidentes anteriores
  * Support for continuous learning based on previous incidents

* 8.7
  * Integração nativa com o ServiceNow
  * Native integration with ServiceNow

* 7.5
  * Integração com ServiceNow para envio de alertas
  * Integration with ServiceNow for alert delivery

### Remediation

#### Script

1) RCA suggested remediation
2) follow link on incident
3) ask AI Assistant to restart pod
4) ask AI assistant to block 0.1 of frontend
4) show kestra calling ansible (container) 
5) show ansible calling kubectl

#### Objectives

* 10.9
  * Sugestão de ações corretivas por IA
  * AI-driven suggestions for corrective actions

* 8.9
  * Permitir execução de scripts locais para remediação
  * Allow execution of local scripts for remediation

* 8.3
  * Permitir automações locais baseadas em scripts
  * Allow local automations based on scripts

* 8.28
  * Executar automações diretamente em ambientes de contêineres (Docker, Kubernetes, etc.)
  * Execute automations directly in container environments (Docker, Kubernetes, etc.)

* 8.1
  * Integração com o Ansible para execução de automações
  * Integration with Ansible for automation execution

# ELSEWHERE

* 9.10
  * Use a password vault for authentication on pages

* 8.18
  * Ability to consume data from external observability tools

* 8.30
  * Ability to define budget limits for cloud-related automations
