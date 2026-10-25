# Packages a binary compiled by the host (local) or a go-build workflow step (CI).
# Go compilation is intentionally kept out of this Dockerfile — see Makefile and
# the ci-docker-build WorkflowTemplate for where the binary is produced.
FROM alpine:3.24@sha256:be2656061b536c1883c4034790e21d0a09c5aaaf51968b89368a3c0371ea2c9a

RUN apk --no-cache add ca-certificates wget

RUN adduser -D -s /bin/sh webhook

WORKDIR /home/webhook

COPY webhook ./webhook
RUN chmod +x ./webhook && chown webhook:webhook ./webhook

USER webhook

EXPOSE 8443

CMD ["./webhook"]
