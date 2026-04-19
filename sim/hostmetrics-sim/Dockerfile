FROM golang:1.24 AS builder
WORKDIR /usr/src/app/

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/root/.cache/go-build go mod download

COPY *.go ./
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -o /go/bin/hostmetrics-sim .

# -----------------------------------------------------------------------------

FROM golang:1.24

WORKDIR /usr/src/app/

COPY --from=builder /go/bin/hostmetrics-sim /usr/src/app/hostmetrics-sim

# Defaults — all overridable at runtime
ENV OTLP_ENDPOINT="localhost:4317"
ENV HOST_COUNT="10"
ENV COLLECT_INTERVAL="60s"
ENV HOST_PREFIX="sim-host"

CMD ["/usr/src/app/hostmetrics-sim"]
