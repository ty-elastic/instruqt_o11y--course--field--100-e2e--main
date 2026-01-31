
import logging
import json
import requests
from datetime import datetime, timezone
import re
#import yaml
import ruamel.yaml
import os
import click
import sys
from ruamel.yaml import YAML
from ruamel.yaml.compat import StringIO
from dotenv import dotenv_values
from io import StringIO

class MyYAML(YAML):
    def dump(self, data, stream=None, **kw):
        inefficient = False
        if stream is None:
            inefficient = True
            stream = StringIO()
        YAML.dump(self, data, stream, **kw)
        if inefficient:
            return stream.getvalue()


def load_prompt(kibana_server, kibana_auth):

    body = {
        "limit": 50,
        "page": 1,
        "query": ""
    }
    
    resp = requests.post(f"{kibana_server}/api/workflows/search",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())

    workflow_id = None
    
    for workflow in resp.json()['results']:
        try:
            print(workflow['name'])
            if workflow['name'] == 'remediation_restart_service':
                workflow_id = workflow['id']
                break
        except:
            print("exception")
            
    with open("prompt/instructions.xml", 'r') as instructions:
        instructions_txt = instructions.read()  # Read the entire content of the file

        
        instructions_txt = instructions_txt.replace("{WORKFLOW_ID}", workflow_id)

        with open("prompt/prompt.json", 'r') as prompt:
            #content = file.read()
            prompt = json.load(prompt)
            prompt['text'] = instructions_txt

            #print(prompt)

            resp = requests.put(f"{kibana_server}/internal/observability_ai_assistant/kb/user_instructions",
                                json=prompt,
                                headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            print(resp.json())

def load_knowledge(kibana_server, kibana_auth):
    directory_path = "knowledge"
    target_extension = ".json"

    entries = []
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    knowledge = json.load(fileo)
                    entries.append(knowledge)
    #print(entries)
    body = {
        "entries": entries
    }
    resp = requests.post(f"{kibana_server}/internal/observability_ai_assistant/kb/entries/import",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    print(resp.json())

def load_new_knowledge(es_host, es_auth):
    directory_path = "knowledge"
    target_extension = ".json"

    mappings={
        "mappings": {
            "properties": {
                "text": {
                    "type": "semantic_text"
                },
                "id": {
                    "type": "keyword"
                },
                "title": {
                    "type": "semantic_text"
                }
            }
        }
    }

    resp = requests.put(f"{es_host}/rca_knowledge",
                        json=mappings,
                        headers={"Content-Type": "application/json", f"Authorization": es_auth})
    print(resp.json())

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    jcontent = json.load(fileo)

                    resp = requests.post(f"{es_host}/rca_knowledge/_doc/",
                    json=jcontent,
                    headers={"Content-Type": "application/json", f"Authorization": es_auth})
                    print(resp.json())





def backup_workflows(kibana_server, kibana_auth):
    
    body = {
        "limit": 50,
        "page": 1,
        "query": ""
    }
    
    resp = requests.post(f"{kibana_server}/api/workflows/search",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for workflow in resp.json()['results']:
        # with open(f"workflows/{workflow['definition']['name']}.json", "w") as json_file:
        #     json.dump(workflow['definition'], json_file, indent=2)
        with open(f"workflows/{workflow['definition']['name']}.yaml", "w") as yaml_file:
            #yaml_file.write(workflow['yaml'])
            #yaml.dump(workflow['definition'], yaml_file, default_flow_style=False)
  
  
            yaml = MyYAML()

            yaml_stream = StringIO(workflow['yaml'])
            parsed = yaml.load(yaml_stream)
            
            print(parsed['name'])
            
            if 'consts' in parsed:
                if 'kbn_host' in parsed['consts']:
                    parsed['consts']['kbn_host'] = 'TBD'
                if 'kbn_auth' in parsed['consts']:
                    parsed['consts']['kbn_auth'] = 'TBD'
                if 'es_host' in parsed['consts']:
                    parsed['consts']['es_host'] = 'TBD'   
                if 'ai_connector' in parsed['consts']:
                    parsed['consts']['ai_connector'] = 'TBD'   
                if 'ai_proxy' in parsed['consts']:
                    parsed['consts']['ai_proxy'] = 'TBD'  
                if 'snow_host' in parsed['consts']:
                    parsed['consts']['snow_host'] = 'TBD'  
                if 'snow_auth' in parsed['consts']:
                    parsed['consts']['snow_auth'] = 'TBD'  

            yaml = MyYAML()
            yaml.width = float("inf") # Set the width attribute of the YAML instance

            #yaml.dump(parsed)
            yaml.dump(parsed, yaml_file)
  
  
def delete_existing_workflow(kibana_server, kibana_auth, es_host, workflow_name):
    
    body = {
        "limit": 50,
        "page": 1,
        "query": ""
    }
    
    print("search workflows...")
    resp = requests.post(f"{kibana_server}/api/workflows/search",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    print("done")
    
    for workflow in resp.json()['results']:
        try:
        
            
            if workflow['name'] == workflow_name:
                print(f"deleting {workflow['name']}")
                delete_body = {
                    "ids": [f"{workflow['id']}"]
                }
                #print(delete_body)
                
                resp = requests.delete(f"{kibana_server}/api/workflows",
                                    json=delete_body,
                                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                print(resp.json())
        except Exception as e:
            print(e)        
                

def load_workflows(kibana_server, kibana_auth, es_host, ai_connector, ai_proxy, snow_host, snow_auth):

    directory_path = "workflows"
    target_extension = ".yaml"

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                try:
                    full_path = os.path.join(root, file)
                    with open(full_path, 'r') as fileo:
                        #content = file.read()  # Read the entire content of the file
                        #parsed = yaml.load(content)
                        #content = file.read()
                        #print(content)
                        #print(full_path)
                        
                        yaml = MyYAML()

                        parsed = yaml.load(fileo)
                        
                        delete_existing_workflow(kibana_server, kibana_auth, es_host, parsed['name'])
                        print(f"loading {parsed['name']}")
                        
                        # parsed['consts']['kbn_host'] = kibana_server
                        # parsed['consts']['kbn_auth'] = kibana_auth
                        # parsed['consts']['es_host'] = es_host    
                        # parsed['consts']['ai_connector'] = ai_connector   
                        # parsed['consts']['ai_proxy'] = ai_proxy  
                        # parsed['consts']['snow_host'] = snow_host   
                        # parsed['consts']['snow_auth'] = snow_auth              
                        
                        yaml = MyYAML()
                        yaml.width = float("inf") # Set the width attribute of the YAML instance

                        #yaml.dump(parsed)
                        out = yaml.dump(parsed)
                        body = {
                            "yaml": out
                        }
                        #print(out)
                        

                        resp = requests.post(f"{kibana_server}/api/workflows",
                                            json=body,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                        print(resp.json())
                except Exception as e:
                    print(e)

#

def load_synthetics(kibana_server, kibana_auth):

    directory_path = "synthetics"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    synthetic = json.load(fileo)

                    #print(synthetic)
                    resp = requests.post(f"{kibana_server}/api/synthetics/monitors",
                                        json=synthetic,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     
 

def load_rules(kibana_server, kibana_auth, es_host, connect_alerts=True):

    body = {
        "limit": 50,
        "page": 1,
        "query": ""
    }
    
    resp = requests.post(f"{kibana_server}/api/workflows/search",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    alert_queue_id = None
    for workflow in resp.json()['results']:
        if workflow['name'] == 'alert_queue':
            alert_queue_id = workflow['id']

    directory_path = "rules"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    rule = json.load(fileo)
                    if connect_alerts:
                        rule['actions'][0]['params']['subActionParams']['workflowId'] = alert_queue_id
                    else:
                        del rule['actions']
                    #print(rule)
                    resp = requests.post(f"{kibana_server}/api/alerting/rule",
                                        json=rule,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     

def delete_existing_agent_tool(kibana_server, kibana_auth, tool_id):

    try:
        resp = requests.delete(f"{kibana_server}/api/agent_builder/tools/{tool_id}",
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
        print(resp.json())
    except Exception as e:
        print(e)        
               

def load_agent_tools(kibana_server, kibana_auth):
    body = {
        "limit": 50,
        "page": 1,
        "query": ""
    }
    workflows_resp = requests.post(f"{kibana_server}/api/workflows/search",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})


    directory_path = "tools"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    tool = json.load(fileo)
                    del tool['readonly']

                    print(f"loading tool {tool['id']}")

                    if tool['type'] == 'workflow':
                        for workflow in workflows_resp.json()['results']:
                            #print(workflow)
                            if workflow['name'] == tool['id']:
                                print("HERE!!!")
                                tool['configuration']['workflow_id'] = workflow['id']

                    delete_existing_agent_tool(kibana_server, kibana_auth, tool['id'])

                    #print(tool)
                    resp = requests.post(f"{kibana_server}/api/agent_builder/tools",
                                        json=tool,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     
 


def backup_agent_tools(kibana_server, kibana_auth):
    
    resp = requests.get(f"{kibana_server}/api/agent_builder/tools", 
                         json={},
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for tool in resp.json()['results']:
        #print(tool)
        if 'rca' in tool['tags']:
            
            with open(f"tools/{tool['id']}.json", "w") as json_file:
                json.dump(tool, json_file)

def delete_existing_agent(kibana_server, kibana_auth, agent_id):

    try:
        resp = requests.delete(f"{kibana_server}/api/agent_builder/agents/{agent_id}",
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
        print(resp.json())
    except Exception as e:
        print(e)        
               

def load_agents(kibana_server, kibana_auth):
    
    directory_path = "agents"
    target_extension = ".json"
    
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as fileo:
                    #content = file.read()
                    agent = json.load(fileo)
                    del agent['readonly']
                    del agent['type']

                    delete_existing_agent(kibana_server, kibana_auth, agent['id'])

                    #print(agent)
                    resp = requests.post(f"{kibana_server}/api/agent_builder/agents",
                                        json=agent,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     
 

def backup_agents(kibana_server, kibana_auth):
    
    resp = requests.get(f"{kibana_server}/api/agent_builder/agents", 
                         json={},
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    print(resp.json())
    
    for agent in resp.json()['results']:
        #print(agent)
        if 'labels' in agent and 'rca' in agent['labels']:
            
            with open(f"agents/{agent['id']}.json", "w") as json_file:
                json.dump(agent, json_file)

def run_workflow(kibana_server, kibana_auth, workflow_name):
    
      
    body = {
        "limit": 50,
        "page": 1,
        "query": ""
    }
    
    resp = requests.post(f"{kibana_server}/api/workflows/search",
                        json=body,
                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
    #print(resp.json())
    
    for workflow in resp.json()['results']:
        if workflow['name'] == workflow_name:
            resp2 = requests.post(f"{kibana_server}/api/workflows/{workflow['id']}/run",
                            json={"inputs":{}},
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            print(resp2.json())
            break


@click.command()
@click.option('--kibana_host', default="", help='address of kibana server')
@click.option('--es_host', default="", help='address of elasticsearch server')
@click.option('--es_apikey', default="", help='apikey for auth')
@click.option('--es_authbasic', default="", help='basic for auth')
@click.option('--connect_alerts', default=True, help='connect alerts to workflow')
@click.option('--snow_host', default="TBD", help='snow host')
@click.option('--snow_authbasic', default="TBD", help='basic for auth')
@click.option('--ai_connector', default="Elastic-Managed-LLM", help='ai connector id')
@click.option('--ai_proxy', default="https://tbekiares-demo-aiassistantv2-1059491012611.us-central1.run.app", help='ai proxy host')
@click.argument('action')
def main(kibana_host, es_host, es_apikey, es_authbasic, connect_alerts, ai_connector, ai_proxy, action, snow_host, snow_authbasic):
    
    config = dotenv_values()
    for key, value in config.items():
        print(f"{key}: {value}")

    if kibana_host == "":
        kibana_host = config['elasticsearch_kibana_endpoint']
    if es_host == "":
        es_host = config['elasticsearch_es_endpoint']
    if es_apikey == "" and es_authbasic == "":
        es_apikey = config['elasticsearch_api_key']

    if snow_host == "TBD" and 'snow_host' in config:
        snow_host = config['snow_host']
    if snow_authbasic == "TBD" and 'snow_authbasic' in config:
        snow_authbasic = config['snow_authbasic']
    if snow_authbasic != "TBD":
        snow_auth = f"Basic {snow_authbasic}"
    else:
        snow_auth = "TBD"

    if es_authbasic != "":
        auth = f"Basic {es_authbasic}"
    else:
        auth = f"ApiKey {es_apikey}"
    
    if action == 'load_workflows':
        print("LOADING WORKFLOWS")
        load_workflows(kibana_host, auth, es_host, ai_connector, ai_proxy, snow_host, snow_auth)
        #run_workflow(kibana_host, auth, 'setup')
        #run_workflow(kibana_host, auth, 'topology')
    elif action == 'load_alerts':
        load_rules(kibana_host, auth, es_host, connect_alerts)
    elif action == 'backup_workflows':
        backup_workflows(kibana_host, auth)
    elif action == 'load_knowledge':
        #load_knowledge(kibana_host, auth)
        load_new_knowledge(es_host, auth)
        print('done')
    elif action == 'load_prompt':
        load_prompt(kibana_host, auth)
        print('done')
    elif action == 'load_synthetics':
        load_synthetics(kibana_host, auth)
        print('done')
    elif action == 'backup_tools':
        backup_agent_tools(kibana_host, auth)
        print('done')
    elif action == 'backup_agents':
        backup_agents(kibana_host, auth)
        print('done')
    elif action == 'load_agents':
        load_agents(kibana_host, auth)
        print('done')
    elif action == 'load_tools':
        load_agent_tools(kibana_host, auth)
        print('done')
    elif action == 'load':
        load_agents(kibana_host, auth)
        load_workflows(kibana_host, auth, es_host, ai_connector, ai_proxy, snow_host, snow_auth)
        load_agent_tools(kibana_host, auth)
        load_rules(kibana_host, auth, es_host, connect_alerts)
        load_new_knowledge(es_host, auth)
        run_workflow(kibana_host, auth, 'setup')
        print('done')

    elif action == 'backup':
        backup_agents(kibana_host, auth)
        backup_agent_tools(kibana_host, auth)
        backup_workflows(kibana_host, auth)
        print('done')
    elif action == 'run_setup':
        run_workflow(kibana_host, auth, 'setup')

if __name__ == '__main__':
    main()
