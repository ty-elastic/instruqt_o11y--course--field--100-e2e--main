
import logging
import json
import requests
from datetime import datetime, timezone
import re
import yaml
import os

# kibana_server="https://581b85187ee040c3bc41f917001ef0b7.us-west2.gcp.elastic-cloud.com"
# kibana_auth="ApiKey U1ZyZjdaa0I4eVREU3ZXeGx6bm06cnRpNUhkMldyYlQ1NjNaTGt5UExJQQ=="

kibana_server="https://snap-ae8a92.kb.us-west2.gcp.elastic-cloud.com"
kibana_auth="ApiKey OEpsYkY1b0JyVktacWxPV1VITGo6Z2d2MmRZYXdTQkpOZ1dhMmVXYmo0Zw=="

def backup(kibana_server, kibana_auth):
    
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
            yaml_file.write(workflow['yaml'])
            #yaml.dump(workflow['definition'], yaml_file, default_flow_style=False)
            
#backup(kibana_server, kibana_auth)

def load(kibana_server, kibana_auth):

    directory_path = "workflows"
    target_extension = ".yaml"

    matching_files = []

    for root, dirs, files in os.walk(directory_path):
        for file in files:
            if file.endswith(target_extension):
                full_path = os.path.join(root, file)
                with open(full_path, 'r') as file:
                    content = file.read()  # Read the entire content of the file
                    body = {
                        "yaml": content
                    }
                    #print(body)
                    resp = requests.post(f"{kibana_server}/api/workflows",
                                        json=body,
                                        headers={"origin": kibana_server,f"Authorization": kibana_auth, "kbn-xsrf": "true", "Content-Type": "application/json", "x-elastic-internal-origin": "Kibana"})
                    print(resp.json())

load(kibana_server, kibana_auth)