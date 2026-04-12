IMAGE      := docker.io/st0rmingbr4in/memory-webhook
PLATFORM   := linux/amd64
BINARY     := webhook-linux-amd64

# Single source of truth: Go version comes from go.mod (e.g. "go 1.25.0" → "1.25")
GO_VERSION := $(shell grep '^go ' go.mod | awk '{print $$2}' | cut -d. -f1-2)

.PHONY: test build push clean

test:
	go test ./...

# Build without pushing (local verification)
build: $(BINARY)
	docker buildx build --platform $(PLATFORM) -f Dockerfile.local -t $(IMAGE):latest .

# Cross-compile on host then package — avoids Go GC crashes under QEMU amd64 emulation.
# The main Dockerfile (used by CI on native amd64) receives GO_VERSION via --build-arg.
push: $(BINARY)
	docker buildx build --platform $(PLATFORM) -f Dockerfile.local -t $(IMAGE):latest --push .
	$(MAKE) clean

# CI target: full in-container build using Go version from go.mod
build-ci:
	docker buildx build --platform $(PLATFORM) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		-t $(IMAGE):latest --push .

$(BINARY):
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o $(BINARY) main.go

clean:
	rm -f $(BINARY)
