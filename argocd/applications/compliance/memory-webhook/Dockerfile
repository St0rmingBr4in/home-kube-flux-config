# Build stage
FROM golang:1.25-alpine@sha256:660f0b83cf50091e3777e4730ccc0e63e83fea2c420c872af5c60cb357dcafb2 AS builder

WORKDIR /app

# Copy go.mod first for better Docker layer caching
COPY go.mod ./

# Copy source code
COPY main.go ./

# Download dependencies and build
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o webhook main.go

# Runtime stage
FROM alpine:3.18

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