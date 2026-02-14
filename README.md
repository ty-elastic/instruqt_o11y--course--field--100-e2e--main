# Local Development

If you'd like to play with this locally, you will need an accessible Kubernetes cluster to deploy the services and a modern (latest?) ECH, Serverless, or Self-Managed Elastic cluster.

## Kubernetes

Your local kubernetes context must point to a valid K8s cluster when you run the build script. If you'd like to create a k8s cluster in GCP, you can run:
```bash
csp/gcp/cluster.sh -t {your_supervisors_last_name} -u {your firstlast name together}
```

## Build services

```bash
./build.sh -b true 
```

## Deploy services for Serverless or ECH w/ MOTel

| Flag | Required | Function |
|---|---|---|
| f | Yes | Enable features on your ES cluster |
| w | Yes | Deploy assets to your ES cluster |
| p | No | Deploy OTel profiling |
| m | No | Deploy private synthetics |
| g | No | Deploy Prometheus + Grafana for Metrics comparison |
| e | No | Enable remote remediation |
| n | No | Enable go zero instrumentation (ebpf) |


## Everything
```bash
./build.sh -c o11y--course--field--100-e2e -b false -d true -s all -o serverless -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -f true -p true -m true -w true -g true -e cluster
```

## Redeploy Services
```bash
./build.sh -c o11y--course--field--100-e2e -d force -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL
```

## Local Build
```bash
./build.sh -c testing -b true -x true -d true -s all -o serverless -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -f true -p true -m true -w true -g true -e cluster
```