from flask import Flask, request, abort
import logging
import tolerantjson as tjson
import json
import requests
from datetime import datetime, timezone
import re
import time
   
app = Flask(__name__)
app.logger.setLevel(logging.INFO)

TIMEOUT = 10*60
RETRIES_DEFAULT = 5

WORKFLOW_TIMEOUT = 5*60

@app.get('/health')
def get_health():
    return {'kernel': 'ok' }

def _observability_ai_assistant_chat_complete_private(body, kibana_server, kibana_auth):
    
    modified_body = {}

    modified_body['instructions'] = []
    if 'instructions' in body:
        modified_body['instructions'].extend(body['instructions'])

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
   
    if 'connectorId' in body:
        modified_body['connectorId'] = body['connectorId']
    else:
        modified_body['connectorId'] = 'Elastic-Managed-LLM'
        
    if 'result' not in body:
        body['result'] = True
        
    if body['result'] == True:
        modified_body['instructions'].append("At the end of your response if you did not reach a function limit while trying to answer the request, output the fields requested in a single JSON object, prefixed with '```json' and postfixed with '```'.  The value of the fields is intended to be read by humans, and should not include nested json or xml, but can include markdown.")

    modified_body['disableFunctions'] = False

    modified_body['scopes'] = ['observability']
    modified_body['screenContexts'] = []

    retries = 0
    if 'retries' in body:
        retries = body['retries']
    else:
        retries = RETRIES_DEFAULT
        
    for i in range(retries):
        print(f'-----------')
        print(f'calling ai assistant ({i} / {retries})...')  

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
            raw_lines = []
            
            if resp.encoding is None:
                resp.encoding = 'utf-8'
            
            for line in resp.iter_lines(decode_unicode=True, chunk_size=10):
                raw_lines.append(line)
                try:
                    if line:
                        jline = json.loads(line)
                        if 'type' in jline:
                            if jline['type'] == 'messageAdd':
                                message_adds.append(jline)
                            elif jline['type'] == 'conversationCreate':
                                modified_body['conversationId'] = jline['conversation']['id']
                            elif jline['type'] == 'conversationUpdate':
                                modified_body['conversationId'] = jline['conversation']['id']
                            # else:
                            #     print(f"skipping type={jline['type']}")
                                
                except Exception as e:
                    print(f"error parsing ai assistant", e)

            print(f'received: {message_adds}')
            if len(message_adds) == 0:
                print(f"NO MESSAGES: {raw_lines}")
            else:
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
                output['lastMessage'] = last_response
                
                if body['result'] == True:     
                    pattern = re.escape('```json') + r"(.*)" #+ re.escape('```')
                    match = re.search(pattern, last_response, re.DOTALL)
                    if match:
                        extracted_content = match.group(1)
                        extracted_content = extracted_content.replace('\\n', '')
                        extracted_content = extracted_content.replace('\\"', '"')
                        
                        print("HERE111")
                        decoded_content = tjson.tolerate(extracted_content)
                        output['result'] = decoded_content
                        print(decoded_content)
                        print("HER!E")

                        print("HER!E2")

                        marker_index = last_response.find("```json")
                        # If the marker is found, slice the string up to that index
                        if marker_index != -1:
                            print("HER!E3")
                            output['lastMessage'] = last_response[:marker_index]
                            print("HERE1112")
                            print(output['lastMessage'])
                        else:
                            # If the marker is not found, the original string remains
                            output['lastMessage'] = last_response

                        return output, 200
                else:
                    return output, 200

        except Exception as e:
            print(f"exception calling ai assistant", e)
            
        print('incomplete response, retrying...')
        modified_body['messages'].append(
            {
                "@timestamp": f"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3] + 'Z'}",
                "message": {
                    "role": "user",
                    "content": "please continue to try to service my request"
                }
            })
            
    
    print(f"giving up calling ai assistant")
    return {"result": "no output"}, 500

@app.post('/api/observability_ai_assistant/chat/complete')
def observability_ai_assistant_chat_complete():    
    body = request.get_json()
    #print(body)
    
    print('req')
    
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
