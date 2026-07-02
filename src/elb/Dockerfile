FROM golang:1.25 AS builder
WORKDIR /usr/src/app/

COPY go.* ./
COPY *.go ./
RUN --mount=type=cache,target=/root/.cache/go-build go build -o /go/bin/elb

# -----------------------------------------------------------------------------

FROM golang:1.25

WORKDIR /usr/src/app/

COPY --from=builder /go/bin/elb /usr/src/app/elb
COPY config.example.yaml /usr/src/app/config.yaml

# Ports are configured per load balancer in config.yaml; EXPOSE is documentary.
EXPOSE 8080
CMD [ "/usr/src/app/elb", "-config", "/usr/src/app/config.yaml" ]
