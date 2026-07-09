# 1. Use the slim variant for a smaller image footprint
FROM debian:12-slim

# 2. Prevent interactive prompts during package installation
ARG DEBIAN_FRONTEND=noninteractive

ENV COURSE=o11y--course--field--100-e2e--serverless
ENV ELASTICSEARCH_URL=""
ENV ELASTICSEARCH_APIKEY=""
ENV FLEET_URL=""
ENV KIBANA_URL=""
ENV INGEST_URL=""

# 4. Install required tools and dependencies cleanly
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl tar gpg \
    ca-certificates \
    gettext-base jq \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get install ca-certificates curl
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get update && apt-get install -y google-cloud-cli


RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

RUN apt-get update && apt-get install -y --no-install-recommends google-cloud-cli-gke-gcloud-auth-plugin

WORKDIR /superdemo

COPY agents agents
COPY assets assets
COPY k8s k8s
COPY utils utils

COPY build.sh .
COPY install.sh .

ENV KUBECONFIG=/superdemo/.kube/kubeconfig

CMD /superdemo/install.sh