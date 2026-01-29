# Observability AI Assistant Proxy

A stateless proxy to:

* allow for synchronous, monolithic JSON response from the existing AI Assistant API (instead of NDJSON)
* support for conversationId (dynamically load conversation history) and conversationHistory (ephemeral, passed between calls)
* support for automatic retries when `function_call_limit_exceeded` is returned
* support for a consistent, structured JSON response

## Rules

Please do not share this repo, README, or the publicly hosted proxy outside of Elastic. (DO NOT SHARE WITH CUSTOMERS)

## URL

https://tbekiares-demo-aiassistantv1-1059491012611.us-central1.run.app

## Method

POST

## Headers

| Header | Description | Example |
|--------|-------------|---------|
| kibana_server | The URL of your Kibana instances | 'https://example.kb.us-west2.gcp.elastic-cloud.com' |
| kibana_auth | Generate an ApiKey from your Elasticsearch instance | 'ApiKey OEpsYkY1b0JyVkthisIsAnExampleRZYXdTQkpOZ1dhMmVXYmo0Zw==' |

## Body

| Field | Description | Required | Type | Default | Example | Notes |
|--------|-------------|---------|-------------|---------|---------|---------|
| result | whether to output requested fields as structured `json` in `result.*` | No | `boolean` | `true` | `true` |
| retries | number of times to retry the call on failure or on `function_call_limit_exceeded` | No | `number` | `5` | `5` |
| persist | whether to save this conversation to AI Assistant conversation history | No |  `boolean` | `true` | `false` |
| connectorId | the ID of the LLM connector to use | No | `string` | `Elastic-Managed-LLM` | `Elastic-Managed-LLM` | use `Elastic-Managed-LLM` (on ECH/ESS) to use Elastic's AI service 
| conversationId | the ID an existing AI Assistant conversation (`conversationHistory` will be loaded from this ID if `conversationHistory` is not provided) | No | `string` |
| conversationHistory | `response.conversationHistory` from a previous call to this tool | No | `[object]` | `[]` |
| instructions | an array of instructions to guide the AI Assistant, not included in `conversationHistory` | No | `[string]` | `[]` | `['be kind in your response']` |
| messages | an array of messages for the AI Assistant | Yes | `[{"timestamp": string, "message": {"content": string, "role": string}}]` | | `[{"timestamp": "now", "message": {"content": "say hello", "role": "user"}}]` | use value `now` for timestamp to have `timestamp` value filled with current UTC time

## Examples

Some OneWorkflow examples which leverage this proxy.

### Simple

```yaml
name: Test
enabled: true
triggers:
  - type: manual
consts:
    ai_connector: Elastic-Managed-LLM
    ai_proxy: https://tbekiares-demo-aiassistantv1-1059491012611.us-central1.run.app
    ai_timeout: 10m
    kbn_auth: ApiKey OEpsYkY1b0JyVkthisIsAnExampleRZYXdTQkpOZ1dhMmVXYmo0Zw==
    kbn_host: https://example.kb.us-west2.gcp.elastic-cloud.com

steps:
  - name: test1
    type: http
    with:
      body:
        connectorId: '{{ consts.ai_connector }}'
        messages:
        - '@timestamp': now
          message:
            content: |
              'Output a field named "greeting" with a value of "hello"'
            role: user
      headers:
        Content-Type: application/json
        kibana-auth: '{{ consts.kbn_auth }}'
        kibana-host: '{{ consts.kbn_host }}'
      method: POST
      timeout: '{{ consts.ai_timeout }}'
      url: '{{ consts.ai_proxy }}/api/observability_ai_assistant/chat/complete'

  - name: debug1
    type: console
    with:
      message: '{{ steps.test1.output.data.result | json }}'
```

### Multi-Step w/ Persist

```yaml
name: Test
enabled: true
triggers:
  - type: manual
consts:
    ai_connector: Elastic-Managed-LLM
    ai_proxy: https://tbekiares-demo-aiassistantv1-1059491012611.us-central1.run.app
    ai_timeout: 10m
    kbn_auth: ApiKey OEpsYkY1b0JyVkthisIsAnExampleRZYXdTQkpOZ1dhMmVXYmo0Zw==
    kbn_host: https://example.kb.us-west2.gcp.elastic-cloud.com

steps:
  - name: test1
    type: http
    with:
      body:
        connectorId: '{{ consts.ai_connector }}'
        messages:
        - '@timestamp': now
          message:
            content: |
              'Output a field named "greeting" with a value of "hello"'
            role: user
        persist: true
      headers:
        Content-Type: application/json
        kibana-auth: '{{ consts.kbn_auth }}'
        kibana-host: '{{ consts.kbn_host }}'
      method: POST
      timeout: '{{ consts.ai_timeout }}'
      url: '{{ consts.ai_proxy }}/api/observability_ai_assistant/chat/complete'

  - name: test2
    type: http
    with:
      body:
        connectorId: '{{ consts.ai_connector }}'
        conversationId: '{{ steps.test1.output.data.conversationId }}'
        messages:
        - '@timestamp': now
          message:
            content: |
              'Output a field named "answer" with the answer (yes/no) to the question "Did I just ask you to say hello?"'
            role: user
        persist: true
      headers:
        Content-Type: application/json
        kibana-auth: '{{ consts.kbn_auth }}'
        kibana-host: '{{ consts.kbn_host }}'
      method: POST
      timeout: '{{ consts.ai_timeout }}'
      url: '{{ consts.ai_proxy }}/api/observability_ai_assistant/chat/complete'

  - name: debug2
    type: console
    with:
      message: '{{ steps.test2.output.data.result | json }}'
```

### Multi-Step w/o Persist

```yaml
name: Test
enabled: true
triggers:
  - type: manual
consts:
    ai_connector: Elastic-Managed-LLM
    ai_proxy: https://tbekiares-demo-aiassistantv1-1059491012611.us-central1.run.app
    ai_timeout: 10m
    kbn_auth: ApiKey OEpsYkY1b0JyVkthisIsAnExampleRZYXdTQkpOZ1dhMmVXYmo0Zw==
    kbn_host: https://example.kb.us-west2.gcp.elastic-cloud.com

steps:
  - name: test1
    type: http
    with:
      body:
        connectorId: '{{ consts.ai_connector }}'
        messages:
        - '@timestamp': now
          message:
            content: |
              'Output a field named "greeting" with a value of "hello"'
            role: user
        persist: false
      headers:
        Content-Type: application/json
        kibana-auth: '{{ consts.kbn_auth }}'
        kibana-host: '{{ consts.kbn_host }}'
      method: POST
      timeout: '{{ consts.ai_timeout }}'
      url: '{{ consts.ai_proxy }}/api/observability_ai_assistant/chat/complete'

  - name: test2
    type: http
    with:
      body:
        connectorId: '{{ consts.ai_connector }}'
        conversationHistory: '{{ steps.test1.output.data.conversationHistory | json}}'
        messages:
        - '@timestamp': now
          message:
            content: |
              'Output a field named "answer" with the answer (yes/no) to the question "Did I just ask you to say hello?"'
            role: user
        persist: false
      headers:
        Content-Type: application/json
        kibana-auth: '{{ consts.kbn_auth }}'
        kibana-host: '{{ consts.kbn_host }}'
      method: POST
      timeout: '{{ consts.ai_timeout }}'
      url: '{{ consts.ai_proxy }}/api/observability_ai_assistant/chat/complete'

  - name: debug2
    type: console
    with:
      message: '{{ steps.test2.output.data.result | json }}'
```