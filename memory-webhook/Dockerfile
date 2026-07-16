# Packages a binary compiled by the host (local) or a go-build workflow step (CI).
# Go compilation is intentionally kept out of this Dockerfile — see Makefile and
# the ci-docker-build WorkflowTemplate for where the binary is produced.
FROM alpine:3.24@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

RUN apk --no-cache add ca-certificates wget

RUN adduser -D -s /bin/sh webhook

WORKDIR /home/webhook

COPY webhook ./webhook
RUN chmod +x ./webhook && chown webhook:webhook ./webhook

USER webhook

EXPOSE 8443

CMD ["./webhook"]
