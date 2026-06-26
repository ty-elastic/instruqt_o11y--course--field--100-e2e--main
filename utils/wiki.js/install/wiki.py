import json
from pathlib import Path
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
import click

def request_retry(method, url, json=None, headers=None, timeout=5, max_retries=5):
    if headers is None:
        headers = {}

    session = requests.Session()
    
    # Configure retry logic
    retry_strategy = Retry(
        total=max_retries,                  # Total number of attempts
        backoff_factor=1,                   # Waits: 1s, 2s, 4s, 8s... between retries
        status_forcelist=[429, 500, 502, 503, 504], # Retry on these HTTP status codes
        raise_on_status=False               # Returns response instead of raising exception on last fail
    )
    
    # Mount the adapter to both HTTP and HTTPS protocols
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    try:
        # The session will automatically retry up to N times if it hits errors
        response = session.request(method=method.upper(), json=json, url=url, headers=headers, timeout=timeout)
        return response
    except requests.exceptions.RequestException as e:
        print(f"Request completely failed: {e}")
        raise(e)

def es_headers(es_api_key, extra=None):
    headers = {
        "Authorization": f"ApiKey {es_api_key}",
        "Content-Type": "application/json",
    }
    if extra:
        headers.update(extra)
    return headers

def wiki_finalize(wiki_public_url, wiki_private_url):
    payload = {
        "adminEmail": "admin@example.com",
        "adminPassword": "password123",
        "adminPasswordConfirm": "password123",
        "siteUrl": wiki_public_url,
        "telemetry": False,
    }

    try:
        print("finalizing...")
        response = request_retry(method="POST", url=f"{wiki_private_url}/finalize", json=payload)
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    return None

def es_set_mapping(es_url, es_api_key):
    payload = {
        "mappings": {
            "dynamic": False,
            "properties": {
                "_timestamp": {"type": "date"},
                "database": {"type": "keyword"},
                "id": {"type": "keyword"},
                "schema": {"type": "keyword"},
                "table": {"type": "keyword"},
                "public_pages_content": {"type": "semantic_text"},
                "public_pages_description": {"type": "semantic_text"},
                "public_pages_title": {"type": "semantic_text"},
                "public_pages_creatorid": {"type": "long"},
                "public_pages_id": {"type": "long"},
                "public_pages_path": {"type": "keyword"},
            },
        }
    }

    try:
        print("set es mapping...")
        response = request_retry(method="PUT", url=f"{es_url}/wiki", json=payload, headers=es_headers(es_api_key=es_api_key))
        print(f"set es mapping...{response.status_code}")
        return None
    except Exception as e:
        print(e)
        raise(e)

def es_clean(es_url, es_api_key):
    try:
        print("find wiki connector...")
        response = request_retry(method="GET", url=f"{es_url}/_connector", headers=es_headers(es_api_key=es_api_key))
        for connector in response.json()['results']:
            if connector['name'] == 'wiki':
                print(f"find wiki connector...{response.status_code}, {connector['id']}")
                print(f"delete wiki connector {connector['id']}...")
                response = request_retry(method="DELETE", url=f"{es_url}/_connector/{connector['id']}", headers=es_headers(es_api_key=es_api_key))
                print(f"delete wiki connector {connector['id']}...{response.status_code}")
        print("delete wiki index...")
        response = request_retry(method="DELETE", url=f"{es_url}/wiki", headers=es_headers(es_api_key=es_api_key))
        print(f"delete wiki index...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)


def es_create_wiki_connector(es_url, es_api_key):
    payload = {
            "description": "wiki content",
            "index_name": "wiki",
            "is_native": False,
            "name": "wiki",
            "service_type": "postgresql"
        }
    
    try:
        print("create wiki connector...")
        response = request_retry(method="POST", url=f"{es_url}/_connector", json=payload, headers=es_headers(es_api_key=es_api_key))
        if response.ok:
            id = response.json()['id']
            print(f"create wiki connector...{response.status_code}, {id}")
            return id
        else:
            print(response.json())
            response.raise_for_status()
    except Exception as e:
        print(e)
        raise(e)

def es_create_wiki_config(connector_id, es_url, es_api_key):

    payload = {
        "values": {
            "host": "wiki-postgresql",
            "port": 5432,
            "username": "postgres",
            "password": "postgres",
            "database": "wiki",
            "schema": "public",
            "tables": "pages",
            "ssl_enabled": False,
        }
    }

    url = f"{es_url}/_connector/{connector_id}/_configuration"

    try:
        print("create wiki config...")
        response = request_retry(method="PUT", url=url, json=payload, 
                                 headers=es_headers(es_api_key=es_api_key))
        if response.ok:
            print(f"create wiki config...{response.status_code}")
            return None
        else:
            print(response.json())
            response.raise_for_status()
    except Exception as e:
        print(e)
        raise(e)
    
def wiki_get_jwt(wiki_private_url):
    gql_query = """
    mutation ($username: String!, $password: String!, $strategy: String!) {
        authentication {
            login(username: $username, password: $password, strategy: $strategy) {
                responseResult {
                succeeded
                errorCode
                message
                }
                jwt
                continuationToken
            }
        }
    }"""
    
    payload = {
        "query": gql_query,
        "variables": {
            "username": "admin@example.com",
            "password": "password123",
            "strategy": "local",
        },
    }

    try:
        print("get jwt...")
        response = request_retry(method="POST", url=f"{wiki_private_url}/graphql", json=payload)
        jwt = response.json()["data"]["authentication"]["login"]["jwt"]
        print(f"get jwt...{jwt}")
        return jwt
    except Exception as e:
        print(e)
        raise(e)

def wiki_add_content(wiki_private_url, jwt, title, content, description, path):

    gql_query = """
    mutation ($title: String!, $content: String!, $description: String!, $path: String!){
        pages {
            create(
                title: $title
                content: $content
                description: $description
                editor: "markdown"
                isPublished:true
                isPrivate: false
                locale: "en"
                path: $path
                tags:[ "knowledge"]
            ) {
                responseResult {
                    succeeded
                    errorCode
                    message
                }
                page {
                    id
                    path
                    contentType
                }
            }
        }
    }"""

    payload = {
        "query": gql_query,
        "variables": {
            "title": title,
            "content": content,
            "description": description,
            "path": path,
        },
    }

    try:
        print(f"add content {title}...")
        response = request_retry(method="POST", url=f"{wiki_private_url}/graphql", json=payload,
                                 headers={"Authorization": f"Bearer {jwt}"})
        print(f"add content {title}...{response.status_code}")
        return None
    except Exception as e:
        print(e)
        raise(e)

def wiki_load_knowledge(wiki_private_url, jwt, path):
    knowledge_dir = Path(path)
    for file in sorted(knowledge_dir.iterdir()):
        if not file.is_file():
            continue

        data = json.loads(file.read_text())
        page_id = data.get("id")
        title = data.get("title")
        text = data.get("text")

        # print(page_id)
        # print(title)
        # print(text)
        wiki_add_content(wiki_private_url, jwt, title, text, title, page_id)


def es_sync(connector_id, es_url, es_api_key):

    payload = {"id": connector_id, "job_type": "full"}
    try:
        print("sync...")
        response = request_retry(method="POST", url=f"{es_url}/_connector/_sync_job", json=payload, 
                                 headers=es_headers(es_api_key=es_api_key))
        print(f"sync...{response.status_code}")
        return None
    except Exception as e:
        print(e)
        raise(e)

@click.command()
@click.option('--wiki_public_url', default="", help='public address of wiki server')
@click.option('--wiki_private_url', default="", help='private address of wiki server')
@click.option('--es_host', default="", help='url of es')
@click.option('--es_apikey', default="", help='es api key')
@click.option('--action', default="", help='wiki or es')
def main(wiki_public_url, wiki_private_url, es_host, es_apikey, action):
    if action == "wiki_config":
        wiki_finalize(wiki_public_url, wiki_private_url)
        jwt = wiki_get_jwt(wiki_private_url)
        wiki_load_knowledge(wiki_private_url, jwt, "knowledge")
    elif action == "es_create_connector":
        es_clean(es_host, es_apikey)
        connector_id = es_create_wiki_connector(es_host, es_apikey)
        print('{"connector_id": "' + connector_id + '"}')
    elif action == "es_config_connector":
        es_set_mapping(es_host, es_apikey)
        es_create_wiki_config(connector_id, es_host, es_apikey)
        es_sync(connector_id, es_host, es_apikey)

if __name__ == "__main__":
    main()
