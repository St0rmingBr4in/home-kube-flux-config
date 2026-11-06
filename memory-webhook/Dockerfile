# Packages a binary compiled by the host (local) or a go-build workflow step (CI).
# Go compilation is intentionally kept out of this Dockerfile — see Makefile and
# the ci-docker-build WorkflowTemplate for where the binary is produced.
FROM alpine:3.24@sha256:3f4d6b32e26703c6082839234f43769d5046b3ac7c910033911d1e71d8cd630a

RUN apk --no-cache add ca-certificates wget

RUN adduser -D -s /bin/sh webhook

WORKDIR /home/webhook

COPY webhook ./webhook
RUN chmod +x ./webhook && chown webhook:webhook ./webhook

USER webhook

EXPOSE 8443

CMD ["./webhook"]
