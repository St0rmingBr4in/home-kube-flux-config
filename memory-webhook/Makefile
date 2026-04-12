IMAGE    := docker.io/st0rmingbr4in/memory-webhook
PLATFORM := linux/amd64
BINARY   := webhook

# Single source of truth: Go version comes from go.mod (e.g. "go 1.25.0" → "1.25")
GO_VERSION := $(shell grep '^go ' go.mod | awk '{print $$2}' | cut -d. -f1-2)

.PHONY: test build push clean

test:
	go test ./...

# Build image without pushing (local verification)
build: $(BINARY)
	docker buildx build --platform $(PLATFORM) -t $(IMAGE):latest .

# Cross-compile on host then package — avoids Go GC crashes under QEMU amd64 emulation.
push: $(BINARY)
	docker buildx build --platform $(PLATFORM) -t $(IMAGE):latest --push .
	$(MAKE) clean

$(BINARY):
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o $(BINARY) main.go

clean:
	rm -f $(BINARY)
