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
TIMEOUT = 10*60
RETRIES_DEFAULT = 5

@app.get('/health')
def get_health():
    return {'kernel': 'ok' }

def _observability_ai_assistant_chat_complete_private(body, kibana_server, kibana_auth):

    modified_body = {}

    modified_body['instructions'] = []
    if 'instructions' in body:
        modified_body['instructions'].extend(body['instructions'])
    modified_body['instructions'].append("If you reach a function call limit while trying to answer the question, output a field 'result' with a value of 'function_call_limit_exceeded'.")
    modified_body['instructions'].append("At the end of your response, output ONLY the fields requested in a single JSON object, prefixed with '```json' and postfixed with '```'.  The value of the fields is intended to be read by humans, and should not include nested json or xml.")
       
    modified_body['messages'] = []
    if 'conversationHistory' in body:
        modified_body['messages'].extend(body['conversationHistory'])
    elif 'conversationId' in body:
        # load history
        resp = requests.get(f"{kibana_server}/internal/observability_ai_assistant/conversation/{body['conversationId']}",
                                        timeout=TIMEOUT,
                                        stream=True,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "x-elastic-internal-origin": "Kibana"})
        if resp.status_code != 200:
            print(f"error calling ai assistant: {resp.status_code}, {resp.text}")
            resp.raise_for_status()
        conversation_history = resp.json()['messages']
        modified_body['messages'].extend(conversation_history)
        print(f"loaded history: {conversation_history}")
        
    for message in body['messages']:
        if message['@timestamp'] == 'now':
            message['@timestamp'] = f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'}"
        modified_body['messages'].append(message)

    if 'conversationId' in body:
        modified_body['conversationId'] = body['conversationId']
    if 'persist' in body:
        modified_body['persist'] = body['persist']
    else:
        modified_body['persist'] = False
   
    modified_body['connectorId'] = body['connectorId']
    modified_body['disableFunctions'] = False

    modified_body['scopes'] = ['observability']
    modified_body['screenContexts'] = []

    retries = 0
    if 'retries' in body:
        retries = body['retries']
    else:
        retries = RETRIES_DEFAULT
        
    for i in range(retries):
        print(f'calling ai assistant ({i} / {retries}): {modified_body}')  

        try:
            resp = requests.post(f"{kibana_server}/internal/observability_ai_assistant/chat/complete",
                                            json=modified_body,
                                            timeout=TIMEOUT,
                                            stream=True,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            if resp.status_code != 200:
                print(f"error calling ai assistant: {resp.status_code}, {resp.text}")
                resp.raise_for_status()
            
            message_adds = []
            
            for line in resp.iter_lines():
                try:
                    if line:
                        decoded_line = line.decode('utf-8')
                        jline = json.loads(decoded_line)
                        if 'type' in jline:
                            if jline['type'] == 'messageAdd':
                                message_adds.append(jline)
                            elif jline['type'] == 'conversationCreate':
                                modified_body['conversationId'] = jline['conversation']['id']
                            # else:
                            #     print(f"skipping type={jline['type']}")
                                
                except Exception as e:
                    print(e)

            print(f'received: {message_adds}')

            if len(message_adds) > 0:
                # save history
                for message_add in message_adds:
                    modified_body['messages'].append(message_add['message'])
                
                last_message_add = message_adds[len(message_adds)-1]
                last_response = last_message_add['message']['message']['content']
                
                print(f"last_response: {last_response}")
                
                output = {}
                if 'conversationId' in modified_body:
                    output['conversationId'] = modified_body['conversationId']
                output['conversationHistory'] = modified_body['messages']   
                               
                if 'output' not in body or body['output'] is True:
                    pattern = re.escape('```json') + r"(.*?)" + re.escape('```')
                    match = re.search(pattern, last_response, re.DOTALL)

                    if match:
                        extracted_content = match.group(1)
                        extracted_content = extracted_content.replace('\\n', '')
                        extracted_content = extracted_content.replace('\\"', '"')
                        decoded_content = json.loads(extracted_content) 
                        output.update(decoded_content)

                        if 'result' in output and output['result'] == 'function_call_limit_exceeded' and i <= retries:
                            print('function_call_limit_exceeded, retrying...')
                            modified_body['messages'].append(
                                {
                                    "@timestamp": f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'}",
                                    "message": {
                                        "role": "user",
                                        "content": "please continue to try to service my request"
                                    }
                                })
                        else:
                            return output, 200
                else:
                    return output, 200
        except Exception as e:
            print(f"exception calling ai assistant", e)
    
    print(f"giving up calling ai assistant")
    return {"result": "no output"}, 500

# body = {
#     "persist": True,
#     "connectorId": "Elastic-Managed-LLM",
#     "instructions":[],
#     "messages": [
#         {
#             "@timestamp": "2025-10-16T13:54:59.874Z",
#             "message": {
#                 "role": "user",
#                 "content": "say hello"
#             }
#         }
#     ]
# }
# response, code = _observability_ai_assistant_chat_complete_private(body, "https://581b85187ee040c3bc41f917001ef0b7.us-west2.gcp.elastic-cloud.com", "ApiKey U1ZyZjdaa0I4eVREU3ZXeGx6bm06cnRpNUhkMldyYlQ1NjNaTGt5UExJQQ==")
# print(response)
# print(code)

# body = {
#     "persist": True,
#     "connectorId": "Elastic-Managed-LLM",
#     #"conversationHistory": response['conversationHistory'],
#     "conversationId": response['conversationId'],
#     "instructions":[],
#     "messages": [
#         {
#             "@timestamp": "2025-10-16T13:54:59.874Z",
#             "message": {
#                 "role": "user",
#                 "content": "have i asked you to say hello?"
#             }
#         }
#     ]
# }
# response, code = _observability_ai_assistant_chat_complete_private(body, "https://581b85187ee040c3bc41f917001ef0b7.us-west2.gcp.elastic-cloud.com", "ApiKey U1ZyZjdaa0I4eVREU3ZXeGx6bm06cnRpNUhkMldyYlQ1NjNaTGt5UExJQQ==")
# print(response)
# print(code)


# body = {
#     "persist": True,
#     "connectorId": "Elastic-Managed-LLM",
#     "instructions":[],
#     "messages": [
#         {
#             "@timestamp": "2025-10-16T13:54:59.874Z",
#             "message": {
#                 "role": "user",
#                 "content": "Output the current time formatted like '2025-10-22T17:55:54.735Z' and give me the time 1 hour ago formatted like '2025-10-22T17:55:54.735Z'"
#             }
#         }
#     ]
# }
# response, code = _observability_ai_assistant_chat_complete_private(body, "https://581b85187ee040c3bc41f917001ef0b7.us-west2.gcp.elastic-cloud.com", "ApiKey U1ZyZjdaa0I4eVREU3ZXeGx6bm06cnRpNUhkMldyYlQ1NjNaTGt5UExJQQ==")
# print(response)
# print(code)

# body = {'persist': True, 'connectorId': 'Elastic-Managed-LLM', 'instructions': ["We will be creating a case for handling this alert. Can you output a field called 'summary' that summarizes the alert in a few words, a field called 'rca' that does a preliminary root cause analysis based on the alert, and a field called 'severity' with a value of 'low', 'medium', 'high', or 'critical' based on your analysis?"], 'messages': [{'@timestamp': '2025-10-17T17:34:05.237Z', 'message': {'role': 'user', 'content': '<alert>{\n  "id": "e51eeaa1-fa72-49ee-8faa-2da898c19cc2",\n  "index": ".internal.alerts-observability.apm.alerts-default-000001",\n  "timestamp": "2025-10-16T14:26:00.121Z",\n  "evaluation": {\n    "value": 13.89231401561858,\n    "threshold": 10\n  },\n  "reason": "Failed transactions is 14% in the last 5 mins for service: recorder-java, env: trading-2, type: request. Alert when > 10%.",\n  "rule": {\n    "category": "Failed transaction rate threshold",\n    "consumer": "alerts",\n    "execution": {\n      "uuid": "34a41285-51a4-46ed-9504-c3d2683bb9c9",\n      "timestamp": "2025-10-16T14:26:00.121Z"\n    },\n    "name": "Failed transaction rate threshold rule",\n    "parameters": {\n      "threshold": 10,\n      "windowSize": 5,\n      "windowUnit": "m",\n      "environment": "ENVIRONMENT_ALL"\n    },\n    "producer": "apm",\n    "revision": 0,\n    "rule_type_id": "apm.transaction_error_rate",\n    "tags": {},\n    "uuid": "9e33469d-603a-4c1b-bc28-71975ad902b9"\n  },\n  "action_group": "recovered",\n  "flapping": false,\n  "flapping_history": {\n    "0": false,\n    "1": false,\n    "2": false,\n    "3": false,\n    "4": false,\n    "5": false,\n    "6": false,\n    "7": false,\n    "8": false,\n    "9": false,\n    "10": false,\n    "11": false,\n    "12": false,\n    "13": false,\n    "14": false,\n    "15": false,\n    "16": false,\n    "17": false,\n    "18": false,\n    "19": false\n  },\n  "instance": {\n    "id": "recorder-java_trading-2_request"\n  },\n  "maintenance_window_ids": {},\n  "consecutive_matches": 0,\n  "pending_recovered_count": 0,\n  "status": "recovered",\n  "uuid": "e51eeaa1-fa72-49ee-8faa-2da898c19cc2",\n  "workflow_status": "open",\n  "duration": {\n    "us": 660019000\n  },\n  "start": "2025-10-16T13:54:59.874Z",\n  "time_range": {\n    "gte": "2025-10-16T13:54:59.874Z",\n    "lte": "2025-10-16T14:05:59.893Z"\n  },\n  "previous_action_group": "recovered",\n  "end": "2025-10-16T14:05:59.893Z"\n}</alert>\n'}}]}
# response, code = _observability_ai_assistant_chat_complete_private(body, "https://581b85187ee040c3bc41f917001ef0b7.us-west2.gcp.elastic-cloud.com", "ApiKey U1ZyZjdaa0I4eVREU3ZXeGx6bm06cnRpNUhkMldyYlQ1NjNaTGt5UExJQQ==")
# print(response)
# print(code)

# test = '\\n{\\n  \\"summary\\": \\"Failed transaction'
# print(test)
# test = test.replace('\\n', '')
# test = test.replace('\\"', '"')
# print(test)


kibana_server="https://581b85187ee040c3bc41f917001ef0b7.us-west2.gcp.elastic-cloud.com"
kibana_auth="ApiKey U1ZyZjdaa0I4eVREU3ZXeGx6bm06cnRpNUhkMldyYlQ1NjNaTGt5UExJQQ=="
resp = requests.get(f"{kibana_server}/api/workflowExecutions?workflowId={{ steps.get_case_process_id.output.data._source.workflow_id }}",

                                timeout=TIMEOUT,
                                stream=True,
                                headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})


@app.post('/api/observability_ai_assistant/chat/complete')
def observability_ai_assistant_chat_complete():    
    body = request.get_json()
    #print(body)
    
    kibana_server = request.headers.get('kibana-host')
    kibana_auth = request.headers.get('kibana-auth')
    
    try:  
        if 'conversationHistory' in body:
            decoded_history = json.loads(body['conversationHistory'])
            print('conversationHistory is encoded json, decoding')
            body['conversationHistory'] = decoded_history
    except Exception as e:
        print('conversationHistory not encoded json')
    
    response, code = _observability_ai_assistant_chat_complete_private(body, kibana_server, kibana_auth)
    return response, code
