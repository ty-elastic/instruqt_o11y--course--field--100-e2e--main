
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

class MyYAML(YAML):
    def dump(self, data, stream=None, **kw):
        inefficient = False
        if stream is None:
            inefficient = True
            stream = StringIO()
        YAML.dump(self, data, stream, **kw)
        if inefficient:
            return stream.getvalue()

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

            parsed = yaml.load(workflow['definition'])
            
            print(parsed['name'])
            
            parsed['consts']['kbn_host'] = 'TBD'
            parsed['consts']['kbn_auth'] = 'TBD'
            parsed['consts']['es_host'] = 'TBD'    
            parsed['consts']['ai_connector'] = 'TBD'   
            parsed['consts']['ai_proxy'] = 'TBD'  
                                        
            yaml = MyYAML()
            yaml.width = float("inf") # Set the width attribute of the YAML instance

            #yaml.dump(parsed)
            out = yaml.dump(parsed)
            body = {
                "yaml": out
            }
            print(out)  
  
  
def delete_existing(kibana_server, kibana_auth, es_host, workflow_name):
    
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
        try:
        
            print(workflow['name'])
            if workflow['name'] == workflow_name:
                delete_body = {
                    "ids": [f"{workflow['id']}"]
                }
                print(delete_body)
                
                resp = requests.delete(f"{kibana_server}/api/workflows",
                                    json=delete_body,
                                    headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                print(resp.json())
        except Exception as e:
            print(e)        
                

def load_workflows(kibana_server, kibana_auth, es_host, ai_connector, ai_proxy):

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
                        print(full_path)
                        
                        yaml = MyYAML()

                        parsed = yaml.load(fileo)
                        
                        delete_existing(kibana_server, kibana_auth, es_host, parsed['name'])
                        print(parsed['name'])
                        
                        parsed['consts']['kbn_host'] = kibana_server
                        parsed['consts']['kbn_auth'] = kibana_auth
                        parsed['consts']['es_host'] = es_host    
                        parsed['consts']['ai_connector'] = ai_connector   
                        parsed['consts']['ai_proxy'] = ai_proxy  
                                                 
                        
                        yaml = MyYAML()
                        yaml.width = float("inf") # Set the width attribute of the YAML instance

                        #yaml.dump(parsed)
                        out = yaml.dump(parsed)
                        body = {
                            "yaml": out
                        }
                        print(out)
                        

                        resp = requests.post(f"{kibana_server}/api/workflows",
                                            json=body,
                                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                        print(resp.json())
                except Exception as e:
                    print(e)

#

def load_rules(kibana_server, kibana_auth, es_host):

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
                    rule['actions'][0]['params']['subActionParams']['workflowId'] = alert_queue_id
                    print(rule)
                    resp = requests.post(f"{kibana_server}/api/alerting/rule",
                                        json=rule,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())     
            
def run_setup(kibana_server, kibana_auth, es_host):
    
      
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
        if workflow['name'] == 'automated_triage_setup':
            resp2 = requests.post(f"{kibana_server}/api/workflows/{workflow['id']}/run",
                            json={"inputs":{}},
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            print(resp2.json())  
        elif workflow['name'] == 'topology':
            resp2 = requests.post(f"{kibana_server}/api/workflows/{workflow['id']}/run",
                            json={"inputs":{}},
                            headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
            print(resp2.json())  


@click.command()
@click.option('--kibana_host', default="", help='address of kibana server')
@click.option('--es_host', default="", help='address of elasticsearch server')
@click.option('--es_apikey', default="", help='apikey for auth')
@click.option('--ai_connector', default="Elastic-Managed-LLM", help='ai connector id')
@click.option('--ai_proxy', default="https://tbekiares-demo-aiassistantv2-1059491012611.us-central1.run.app", help='ai proxy host')
@click.argument('action')
def main(kibana_host, es_host, es_apikey, ai_connector, ai_proxy, action):
    
    config = dotenv_values()
    for key, value in config.items():
        print(f"{key}: {value}")

    if kibana_host == "":
        kibana_host = config['elasticsearch_kibana_endpoint']
    if es_host == "":
        es_host = config['elasticsearch_es_endpoint']
    if es_apikey == "":
        es_apikey = config['elasticsearch_api_key']
        
    auth = f"ApiKey {es_apikey}"
    

    if action == 'load_workflows':
        load_workflows(kibana_host, auth, es_host, ai_connector, ai_proxy)
        run_setup(kibana_host, auth, es_host)
    elif action == 'load_alerts':
        load_rules(kibana_host, auth, es_host)
    elif action == 'backup_workflows':
        backup_workflows(kibana_host, auth)

if __name__ == '__main__':
    main()
