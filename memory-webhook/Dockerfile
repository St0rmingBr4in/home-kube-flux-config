# Packages a binary compiled by the host (local) or a go-build workflow step (CI).
# Go compilation is intentionally kept out of this Dockerfile — see Makefile and
# the ci-docker-build WorkflowTemplate for where the binary is produced.
FROM alpine:3.23@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11

RUN apk --no-cache add ca-certificates wget

RUN adduser -D -s /bin/sh webhook

WORKDIR /home/webhook

COPY webhook ./webhook
RUN chmod +x ./webhook && chown webhook:webhook ./webhook

USER webhook

EXPOSE 8443

CMD ["./webhook"]
