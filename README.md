# Requirements

* modern Elasticsearch cluster accessible to a k8s cluster

# Bring Your Own k8s Cluster and Elasticsearch cluster

Use this method if you already have a suitable app k8s cluster (at least one node with 16vCPUs and 64GB of RAM).

## Environment variables

Put the following env vars into a `.env` file

```
ELASTICSEARCH_URL=""
ELASTICSEARCH_APIKEY=""
FLEET_URL=""
KIBANA_URL=""
INGEST_URL="" # this needs to have a port (:443) at the end
```

## Install using in-cluster k8s job

Make sure your active k8s context is pointed to your k8s cluster and that you have a `.env` file with the aforementioned environment variables.

`./install.sh`

Wait for job to complete (~15 minutes)

# Bring Your Own Elasticsearch cluster

Use this method if you need to create a suitable app k8s cluster (in GKE). 

## Requirements

* terraform
* gcloud cli and suitable Google Cloud account

## Environment variables

Create a `terraform.tfvars` file in the `install/terraform` folder with the following variables filled in:

```
project = ""
region  = ""
zone    = ""

elasticsearch_url    = ""
elasticsearch_apikey = ""
fleet_url            = ""
kibana_url           = ""
ingest_url           = "" # this needs to have a port (:443) at the end

labels = {
  division   = ""
  org        = ""
  team       = ""
  project    = ""
  keep-until = ""
}
```

## Install using terraform

```
cd terraform
terraform apply
```
