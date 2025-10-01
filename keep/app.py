from flask import Flask, request, abort
import logging
import json
import requests
from datetime import datetime, timezone
import re

app = Flask(__name__)
app.logger.setLevel(logging.INFO)

KB_ADDRESS = ""
ES_ADDRESS = ""
KB_USER = ""
KB_PASS = ""
TIMEOUT = 120

def parse_alerts(keep_alerts_string):
    alerts_cleaned_string = keep_alerts_string.replace('AlertDto', 'dict') \
        .replace('context.', 'context_') \
        .replace('rule.', 'rule_') \
        .replace('AnyHttpUrl', 'str')
        
    alerts = eval(alerts_cleaned_string)

    clean_alerts = []
    clean_alert_ids = []

    for alert in alerts:
        clean = {}
        if 'email' in alert:
            clean['service_email'] = alert['email']
        if 'team' in alert:
            clean['service_team'] = alert['team']
        if 'slack' in alert:
            clean['service_slack'] = alert['slack']
        if 'repository' in alert:
            clean['service_repository'] = alert['repository']

        clean['keep_id'] = alert['id']
        clean['severity'] = alert['severity']
        clean['environment'] = alert['environment']
        clean['description'] = alert['description']
        clean['keep_event_id'] = alert['event_id']
        clean['kibana_alert_url'] = alert['url']
        clean['kibana_rule_id'] = alert['ruleId']
        clean['kibana_rule_name'] = alert['name']
        clean['kibana_alert_id'] = alert['fingerprint']
        clean['host'] = alert['host']
        clean_alert_ids.append(clean['kibana_alert_id'])
        clean_alerts.append(clean)

    return clean_alerts, clean_alert_ids

@app.get('/health')
def get_health():
    return {'kernel': 'ok' }

@app.post('/alarms/clean')
def post_alarms_clean():
    body = request.get_json()
    clean_alarms, clean_alert_ids = parse_alerts(body)
    return {'alarms': json.dumps(clean_alarms), 'alert_ids': json.dumps(clean_alert_ids) }

def alarms_rca(prompt, alert_ids, body=None):    


    if body is None:
        now_utc = datetime.now(timezone.utc)
        content = prompt + " alert_ids = " + ", ".join(alert_ids)
        print(content)
        body = {
            "connectorId": "Elastic-Managed-LLM",
            "disableFunctions": False,
            "messages": [
                {
                    "@timestamp": f"{now_utc.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'}",
                    "message": {
                        "role": "user",
                        "content": content
                    }
                }
            ],
            "persist": True,
            #"actions": [],
            "screenContexts": [],
            "scopes": ["observability"],
            "instructions": ["when you look for alerts, look over the last 7 days. return a json-formatted object with a field called 'title' that is a short 3 word title for the incident, a field called 'description' which is a 15 word description for the incident, and a field called 'summary' which is a detailed summary of the issue and the root cause analysis"]
        }
        print(body)
    resp = requests.post(f"{KB_ADDRESS}/internal/observability_ai_assistant/chat/complete",
                                    json=body,
                                     timeout=TIMEOUT,
                                     auth=(KB_USER, KB_PASS),
                                     headers={'x-elastic-internal-origin': 'Kibana', "kbn-xsrf": "true", "Content-Type": "application/json"})
    #print(resp.text)
    #print("here")
    resp_json = []
    for line in resp.text.strip().split('\n'):
        jline = json.loads(line)
        if jline['type'] == 'chatCompletionMessage':
            resp_json.append(jline)

    #print(resp_json)
    last_msg = resp_json[len(resp_json)-1]
    print(last_msg)
    if 'function_call' in last_msg['message']:
        response = last_msg['message']['function_call']['arguments']['response']
    else:
        response = last_msg['message']['content']
    print(response)

    pattern = re.escape('```json') + r"(.*?)" + re.escape('```')
    match = re.search(pattern, response, re.DOTALL)

    if match:
        extracted_content = match.group(1)
        print(extracted_content)
    else:
        print("No match found.")

    print(extracted_content)
    return extracted_content

    # repaired_json_string = repair_json(resp.text)
    # test = json.loads(repaired_json_string)
    # print(test)

@app.post('/alarms/rca')
def post_alarms_rca():
    body = request.get_json()
    print(body)
    body_json=body
    #body_json = json.loads(body)
    alarms = body_json['alarms']
    print(alarms)

    clean_alarms, clean_alert_ids = parse_alerts(alarms)
    print(clean_alarms)
    print(clean_alert_ids)

    prompt = body_json['prompt']

    res = alarms_rca(prompt, clean_alert_ids)
    print(res)
    return {'result': json.dumps(res)}

def create_case(incident, message, alarms):

    # connector = {
    #     "id": "1397afec-32b7-4d1c-8e73-e948f2be2e2c",
    #     "type": ".servicenow",
    #     "fields": {
    #       "urgency": "1",
    #       "severity": "2",
    #       "impact": "3",
    #       "category": "software",
    #       "subcategory": None,
    #       "additionalFields": None
    #     },
    #     "name": "ServiceNow-Dev"
    # }
    connector = {
        "id": "none",
        "type": ".none",
        "fields": None,
        "name": "none"
      }

    email = []
    team = []
    slack = []
    repo = []
    
    for alarm in alarms:
        if 'service_email' in alarm and alarm['service_email'] not in alarm:
            email.append(alarm['service_email'])
        if 'service_team' in alarm and alarm['service_team'] not in alarm:
            team.append(alarm['service_team'])
        if 'service_slack' in alarm and alarm['service_slack'] not in alarm:
            slack.append(alarm['service_slack'])
        if 'service_repository' in alarm and alarm['service_repository'] not in alarm:
            repo.append(alarm['service_repository'])

    customFields = []
    if len(repo) > 0:
        customFields.append(
            {
                "value": ", ".join(repo),
                "type": "text",
                "key": "e12d4573-bc08-4f5a-a025-8a1e0e988a03"
            }
        )
    if len(email) > 0:
        customFields.append(
            {
                "value": ", ".join(email),
                "type": "text",
                "key": "f9db5293-a224-49f6-b234-dfe9f98fae46"
            }
        )
    if len(team) > 0:
        customFields.append(
            {
                "value": ", ".join(team),
                "type": "text",
                "key": "4cb61712-328a-4a91-adf6-729a15bfd2ad"
            }
        )
    if len(slack) > 0:
        customFields.append(
            {
                "value": ", ".join(slack),
                "type": "text",
                "key": "ba4a4cb1-6ef0-4e6c-919c-6e4ba66111d3"
            }
        )

    body = {
        "tags":["keep"],
        "owner":"observability",
        "title":message['title'],
        "settings":{"syncAlerts":False},
        "connector":connector,
        "description":message['description'],
        "customFields":customFields
    }

    print(body)

    res = requests.post(f"{KB_ADDRESS}/api/cases",
                                    json=body,
                                     timeout=TIMEOUT,
                                     auth=(KB_USER, KB_PASS),
                                     headers={"kbn-xsrf": "true", "Content-Type": "application/json"})
    print(res)
    print(res.json())
    case_id = res.json()['id']
    print(case_id)

    for alarm in alarms:
        body= {
            "query": {
                "term": {
                "_id": {
                    "value": alarm['kibana_alert_id']
                }
                }
            }
        }
        res = requests.get(f"{ES_ADDRESS}/.alerts-observability.*/_search",
                                    json=body,
                                     timeout=TIMEOUT,
                                     auth=(KB_USER, KB_PASS),
                                     headers={"kbn-xsrf": "true", "Content-Type": "application/json"})
        json = res.json()
        index = json['hits']['hits'][0]['_index']

        body = {
            "type": "alert",
            "owner": "observability",
            "alertId": alarm['kibana_alert_id'],
            "index": index,
            "rule": {
                "id": alarm['kibana_rule_id'],
                "name": alarm['kibana_rule_name'],
            }
        }
        print(body)
        
        comment = requests.post(f"{KB_ADDRESS}/api/cases/{case_id}/comments",
                                        json=body,
                                        timeout=TIMEOUT,
                                        auth=(KB_USER, KB_PASS),
                                        headers={"kbn-xsrf": "true", "Content-Type": "application/json"})

        print(comment)

    body = {
        "type": "user",
        "owner": "observability",
        "comment": message['summary']
    }
    print(body)
    
    comment = requests.post(f"{KB_ADDRESS}/api/cases/{case_id}/comments",
                                    json=body,
                                    timeout=TIMEOUT,
                                    auth=(KB_USER, KB_PASS),
                                    headers={"kbn-xsrf": "true", "Content-Type": "application/json"})


@app.post('/case/create')
def post_case():
    body = request.get_json()
    body_json = json.loads(body)
    #print(body_json)
    incident = body_json['incident']
    message = body_json['message']
    print(message)
    test = json.loads(message)
    alarms = body_json['alarms']

    clean_alarms, clean_alert_ids = parse_alerts(alarms)
    print(clean_alarms)
    print(clean_alert_ids)

    create_case(incident, test, clean_alarms)
    return {'result': 'success'}


# response = "ty\n```json\nblah\n```nah"
# pattern = re.escape('```json') + r"(.*?)" + re.escape('```')
# match = re.search(pattern, response, re.DOTALL)

# if match:
#     extracted_content = match.group(1)
#     print(extracted_content)
# else:
#     print("No match found.")

body = {"screenContexts": [], "scopes": ['observability'], 'connectorId': 'Elastic-Managed-LLM', 'disableFunctions': False, 'messages': [{'@timestamp': '2025-09-24T19:11:46.278Z', 'message': {'role': 'user', 'content': 'are the following alert ids related? if so, what is the likely root cause? alert_ids = 07cf381f-be19-43ed-9d2f-2ed1eea0dd04, c8afcfb4-1a97-41c0-b3b9-8096f8268d2e'}}], 'persist': True, 'instructions': ["return a json-formatted object with a field called 'title' that is a short 3 word title for the incident, a field called 'description' which is a 15 word description for the incident, and a field called 'summary' which is a detailed summary of the issue and the root cause analysis"]}

alarms_rca(None, None, body)

# test = '{"model":"unknown","choices":[{"delta":{"content":""},"finish_reason":null,"index":0}],"created":1758742850171,"id":"beb3fc7d-bee1-46da-a0d6-fe94469d2a18","object":"chat.completion.chunk"}'
# jtest = json.loads(test)
# print(jtest)

