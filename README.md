# Install

## Dockerfile

Build the dockerfile:
```
docker build -t superdemo_install .
```

### Environment variables

Provide the following env vars to the docker container (e.g., in a `.env` file):

```
ENV ELASTICSEARCH_URL=""
ENV ELASTICSEARCH_APIKEY=""
ENV FLEET_URL=""
ENV KIBANA_URL=""
ENV INGEST_URL=""
```

### Kubernetes context

Provide an active kubectl context to the docker container.

### Run

```
docker run --env-file .env -v /Users/tyrone.bekiares/.kube/config:/kubeconfig superdemo_install
```

## Shell script

### Environment variables

Define the following env vars:

```
export ELASTICSEARCH_URL=""
export ELASTICSEARCH_APIKEY=""
export FLEET_URL=""
export KIBANA_URL=""
export INGEST_URL=""
```

### Kubernetes context

Ensure you have an active k8s context pointing to the k8s cluster you want to install the services into.

### Run

./install.sh