# Build stage
# GO_VERSION is injected from go.mod at build time (see Makefile).
# Do not edit this value here — update go.mod instead.
ARG GO_VERSION
FROM golang:${GO_VERSION}-alpine AS builder

WORKDIR /app

# Copy go.mod + go.sum first for better Docker layer caching
COPY go.mod go.sum ./

# Download dependencies (avoids full graph resolution of go mod tidy)
RUN go mod download

# Copy source code and build
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o webhook main.go

# Runtime stage
FROM alpine:3.23@sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659

# Install ca-certificates and wget for health checks
RUN apk --no-cache add ca-certificates wget

# Create non-root user first
RUN adduser -D -s /bin/sh webhook

WORKDIR /home/webhook

# Copy the binary and set proper ownership and permissions
COPY --from=builder /app/webhook .
RUN chmod +x ./webhook && chown webhook:webhook ./webhook

# Switch to non-root user
USER webhook

# Expose the webhook port
EXPOSE 8443

# Run the webhook
CMD ["./webhook"]
