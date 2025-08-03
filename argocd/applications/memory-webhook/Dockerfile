# Build stage
FROM golang:1.21-alpine AS builder

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

WORKDIR /root/

# Copy the binary and set execute permissions
COPY --from=builder /app/webhook .
RUN chmod +x ./webhook

# Create non-root user
RUN adduser -D -s /bin/sh webhook

# Switch to non-root user
USER webhook

# Expose the webhook port
EXPOSE 8443

# Run the webhook
CMD ["./webhook"] 