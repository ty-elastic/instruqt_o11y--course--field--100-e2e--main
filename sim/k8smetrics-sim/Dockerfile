FROM golang:1.24 AS builder
WORKDIR /usr/src/app/

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build go mod download

COPY *.go ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -o /go/bin/k8smetrics-sim .

# -----------------------------------------------------------------------------

FROM golang:1.24

WORKDIR /usr/src/app/

COPY --from=builder /go/bin/k8smetrics-sim /usr/src/app/k8smetrics-sim

# Defaults — all overridable at runtime
ENV OTLP_ENDPOINT="localhost:4317"
ENV CLUSTER_NAME="sim-cluster"
ENV NODE_COUNT="3"
ENV NAMESPACE_COUNT="5"
ENV PODS_PER_NODE="10"
ENV CLUSTER_INTERVAL="30s"
ENV KUBELET_INTERVAL="20s"

CMD ["/usr/src/app/k8smetrics-sim"]
