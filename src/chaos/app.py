from flask import Flask, request
import logging
import os
from kubernetes import client, config, utils
import yaml
import tempfile
import json
import datetime
app = Flask(__name__)
app.logger.setLevel(logging.INFO)

def init_otel(): 
    if 'OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED' in os.environ:
        print("enable otel logging")      
        root_logger = logging.getLogger()
        for handler in root_logger.handlers:
            if isinstance(handler, logging.StreamHandler):
                root_logger.removeHandler(handler)
init_otel()

core_api=None
apps_api=None
api=None

deployments=None

def get_current_namespace() -> str | None:
    namespace_file_path = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"
    if os.path.exists(namespace_file_path):
        with open(namespace_file_path, "r") as f:
            return f.read().strip()
    return None

def init_k8s(incluster=True):
    global core_api, apps_api, api, deployments
    
    if incluster:
        config.load_incluster_config()
    else:
        config.load_kube_config()

    core_api = client.CoreV1Api()
    apps_api = client.AppsV1Api()
    api = client.ApiClient()
    
    deployments = get_deployments(os.environ['NAMESPACE'])

def get_deployments(namespace):
    ret = apps_api.list_namespaced_deployment(namespace)
    deployments = {}
    for item in ret.items:
        if 'kubectl.kubernetes.io/last-applied-configuration' in item.metadata.annotations:
            print(item.metadata.name)
            deployments[item.metadata.name] = json.loads(item.metadata.annotations['kubectl.kubernetes.io/last-applied-configuration'])
        
    return deployments

def get_pods(namespace):
    print("Listing pods with their IPs:")
    ret = core_api.list_namespaced_pod(namespace)
    return ret.items

def get_deployment(namespace, name):
    ret = apps_api.read_namespaced_deployment(name=name, namespace=namespace)
    return ret

def delete_deployment(namespace, name):
    return apps_api.delete_namespaced_deployment(name=name, namespace=namespace)

def add_deployment(namespace, body):
    return apps_api.create_namespaced_deployment(body=body, namespace=namespace)

def restart_deployment(namespace, name):
    now = datetime.datetime.utcnow()
    now = str(now.isoformat("T") + "Z")
    body = {
        'spec': {
            'template':{
                'metadata': {
                    'annotations': {
                        'kubectl.kubernetes.io/restartedAt': now
                    }
                }
            }
        }
    }
    return apps_api.patch_namespaced_deployment(name, namespace, body, pretty='true')

def add_deployment_from_yaml(namespace, path):

    with open(path, 'r') as f:
        content = f.read()
        content = content.replace(f"$NAMESPACE", os.environ['NAMESPACE'])
        content = content.replace(f"$REPO", os.environ['REPO']) 
        content = content.replace(f"$COURSE", os.environ['COURSE'])
        content = content.replace(f"$REGION", os.environ['REGION'])
        
        content = content.replace(f"$POSTGRESQL_HOST", os.environ['POSTGRESQL_HOST'])
        content = content.replace(f"$POSTGRESQL_USER", os.environ['POSTGRESQL_USER']) 
        content = content.replace(f"$POSTGRESQL_PASSWORD", os.environ['POSTGRESQL_PASSWORD'])
        content = content.replace(f"$POSTGRESQL_DBNAME", os.environ['POSTGRESQL_DBNAME'])
        content = content.replace(f"$DB_PROTOCOL", os.environ['DB_PROTOCOL'])
        content = content.replace(f"$DB_SETUP", os.environ['DB_SETUP'])
        content = content.replace(f"$DB_OPTIONS", os.environ['DB_OPTIONS'])
        content = content.replace(f"$DB_PORT", os.environ['DB_PORT'])
        content = content.replace(f"$DB_DIALECT", os.environ['DB_DIALECT'])
        
        content = content.replace(f"$SERVICE_VERSION", os.environ['SERVICE_VERSION'])
        content = content.replace(f"$NOTIFIER_ENDPOINT", os.environ['NOTIFIER_ENDPOINT'])          

        with tempfile.NamedTemporaryFile(mode="w", delete_on_close=False, encoding='utf-8') as fw:
            fw.write(content)
            fw.close()
            with open(fw.name, 'r') as fr:
                for doc in yaml.safe_load_all(fr): 
                    if doc is None:
                        continue
                    if 'kind' in doc and doc['kind'] == 'Deployment':
                        return apps_api.create_namespaced_deployment(
                            body=doc,
                            namespace=namespace
                        )

@app.post('/service/<service>/<state>')
def change_service_status(service, state):
    try:
        if state == 'up':
            ret = add_deployment_from_yaml(os.environ['NAMESPACE'], f"yaml/{service}.yaml")
            return {'status': 'success'}, 200
        elif state == 'down':
            ret = delete_deployment(os.environ['NAMESPACE'], service)
            return {'status': 'success'}, 200
        elif state == 'restart':
            ret = restart_deployment(os.environ['NAMESPACE'], service)
            return {'status': 'success'}, 200
    except Exception as e:
        return {'status': 'fail', "reason": e.reason}, e.status

if __name__ == "__main__":
    init_k8s(incluster=False)
else:
    print("incluster")
    init_k8s(incluster=True)
