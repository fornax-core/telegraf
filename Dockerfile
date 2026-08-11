ARG GOLANG_BUILDER_IMAGE=public.ecr.aws/docker/library/golang:1.26
ARG TELEGRAF_BASE_IMAGE=public.ecr.aws/docker/library/telegraf:1.39-alpine

FROM ${GOLANG_BUILDER_IMAGE} AS builder
WORKDIR /src
COPY . .
ARG COMMIT=unknown
ARG BRANCH=unknown
# Fornax build: only the plugins used by the telegraf-ds DaemonSet.
ARG BUILDTAGS=custom,inputs.cpu,inputs.disk,inputs.diskio,inputs.kubernetes,inputs.mem,inputs.net,inputs.processes,inputs.swap,inputs.system,outputs.postgresql
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 make build BUILDTAGS="${BUILDTAGS}" commit=${COMMIT} branch=${BRANCH}

FROM ${TELEGRAF_BASE_IMAGE}
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /src/telegraf /usr/bin/telegraf
ENTRYPOINT ["/usr/bin/telegraf"]
