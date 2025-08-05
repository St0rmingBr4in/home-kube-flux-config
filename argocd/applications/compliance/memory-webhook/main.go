package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
)

var logger *zap.Logger

func init() {
	// Configure structured JSON logging with zap
	config := zap.NewProductionConfig()
	config.Level = zap.NewAtomicLevelAt(zap.DebugLevel)
	config.OutputPaths = []string{"stdout"}
	config.ErrorOutputPaths = []string{"stderr"}
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder

	var err error
	logger, err = config.Build()
	if err != nil {
		panic(fmt.Sprintf("Failed to initialize logger: %v", err))
	}
}

type WebhookServer struct {
	server *http.Server
}

type patchOperation struct {
	Op    string      `json:"op"`
	Path  string      `json:"path"`
	Value interface{} `json:"value,omitempty"`
}

// Memory resource mutation logic
func mutateMemoryResources(pod *corev1.Pod) []patchOperation {
	var patches []patchOperation

	logger.Info("Processing pod for memory mutations",
		zap.String("namespace", pod.Namespace),
		zap.String("name", pod.Name),
		zap.Int("containers", len(pod.Spec.Containers)),
		zap.Int("initContainers", len(pod.Spec.InitContainers)))

	// Process regular containers
	for i, container := range pod.Spec.Containers {
		logger.Info("Processing container",
			zap.Int("index", i),
			zap.String("name", container.Name),
			zap.String("type", "regular"))
		containerPatches := mutateContainerMemory(container, fmt.Sprintf("/spec/containers/%d/resources", i))
		patches = append(patches, containerPatches...)
	}

	// Process init containers
	for i, container := range pod.Spec.InitContainers {
		logger.Info("Processing container",
			zap.Int("index", i),
			zap.String("name", container.Name),
			zap.String("type", "init"))
		containerPatches := mutateContainerMemory(container, fmt.Sprintf("/spec/initContainers/%d/resources", i))
		patches = append(patches, containerPatches...)
	}

	logger.Info("Memory mutation analysis complete",
		zap.String("namespace", pod.Namespace),
		zap.String("name", pod.Name),
		zap.Int("totalPatches", len(patches)))

	return patches
}

func mutateContainerMemory(container corev1.Container, basePath string) []patchOperation {
	var patches []patchOperation
	defaultMemory := "512Mi"

	logger.Info("Analyzing container memory resources",
		zap.String("container", container.Name))

	// Initialize resources if nil
	if container.Resources.Limits == nil && container.Resources.Requests == nil {
		// Case 1: No resources defined - add both limit and request
		patches = append(patches, patchOperation{
			Op:   "add",
			Path: basePath,
			Value: map[string]interface{}{
				"limits": map[string]interface{}{
					"memory": defaultMemory,
				},
				"requests": map[string]interface{}{
					"memory": defaultMemory,
				},
			},
		})
		logger.Info("Added complete resources block",
			zap.String("container", container.Name),
			zap.String("defaultMemory", defaultMemory),
			zap.String("action", "add_full_resources"))
		return patches
	}

	// Handle cases where resources exist but need memory adjustments
	var hasMemoryLimit, hasMemoryRequest bool
	var memoryLimit, memoryRequest interface{}

	if container.Resources.Limits != nil {
		if limit, exists := container.Resources.Limits[corev1.ResourceMemory]; exists && !limit.IsZero() {
			hasMemoryLimit = true
			memoryLimit = limit.String()
			logger.Info("Found existing memory limit",
				zap.String("container", container.Name),
				zap.String("memoryLimit", limit.String()))
		}
	}

	if container.Resources.Requests != nil {
		if request, exists := container.Resources.Requests[corev1.ResourceMemory]; exists && !request.IsZero() {
			hasMemoryRequest = true
			memoryRequest = request.String()
			logger.Info("Found existing memory request",
				zap.String("container", container.Name),
				zap.String("memoryRequest", request.String()))
		}
	}

	if hasMemoryLimit && hasMemoryRequest {
		// Case 2: Both exist - make request equal to limit (Guaranteed QoS)
		if memoryLimit != memoryRequest {
			patches = append(patches, patchOperation{
				Op:    "replace",
				Path:  basePath + "/requests/memory",
				Value: memoryLimit,
			})
			logger.Info("Adjusted memory request to match limit for Guaranteed QoS",
				zap.String("container", container.Name),
				zap.String("previousRequest", memoryRequest.(string)),
				zap.String("newRequest", memoryLimit.(string)),
				zap.String("action", "guarantee_qos"))
		} else {
			logger.Info("Memory resources already optimal",
				zap.String("container", container.Name),
				zap.String("memory", memoryLimit.(string)),
				zap.String("qos", "Guaranteed"))
		}
	} else if hasMemoryLimit && !hasMemoryRequest {
		// Case 3: Only limit exists - add request to match limit

		// Check if requests object exists
		if container.Resources.Requests == nil {
			patches = append(patches, patchOperation{
				Op:   "add",
				Path: basePath + "/requests",
				Value: map[string]interface{}{
					"memory": memoryLimit,
				},
			})
			logger.Info("Created requests block with memory request",
				zap.String("container", container.Name),
				zap.String("memoryRequest", memoryLimit.(string)),
				zap.String("action", "add_requests_block"))
		} else {
			patches = append(patches, patchOperation{
				Op:    "add",
				Path:  basePath + "/requests/memory",
				Value: memoryLimit,
			})
			logger.Info("Added memory request to match limit",
				zap.String("container", container.Name),
				zap.String("memoryRequest", memoryLimit.(string)),
				zap.String("action", "add_memory_request"))
		}
	} else if !hasMemoryLimit && hasMemoryRequest {
		// Case 4: Only request exists - add limit to match request

		// Check if limits object exists
		if container.Resources.Limits == nil {
			patches = append(patches, patchOperation{
				Op:   "add",
				Path: basePath + "/limits",
				Value: map[string]interface{}{
					"memory": memoryRequest,
				},
			})
			logger.Info("Created limits block with memory limit",
				zap.String("container", container.Name),
				zap.String("memoryLimit", memoryRequest.(string)),
				zap.String("action", "add_limits_block"))
		} else {
			patches = append(patches, patchOperation{
				Op:    "add",
				Path:  basePath + "/limits/memory",
				Value: memoryRequest,
			})
			logger.Info("Added memory limit to match request",
				zap.String("container", container.Name),
				zap.String("memoryLimit", memoryRequest.(string)),
				zap.String("action", "add_memory_limit"))
		}
	} else {
		// Case 5: Neither limit nor request exist but resources object exists
		// Add both with default values
		if container.Resources.Limits == nil {
			logger.Warn("Resources block exists but both limits and requests are nil",
				zap.String("container", container.Name))
		}

		patches = append(patches, patchOperation{
			Op:    "add",
			Path:  basePath + "/limits/memory",
			Value: defaultMemory,
		})
		patches = append(patches, patchOperation{
			Op:    "add",
			Path:  basePath + "/requests/memory",
			Value: defaultMemory,
		})
		logger.Info("Added default memory resources",
			zap.String("container", container.Name),
			zap.String("defaultMemory", defaultMemory),
			zap.String("action", "add_default_memory"))
	}

	return patches
}

func (ws *WebhookServer) mutate(w http.ResponseWriter, r *http.Request) {
	logger.Info("Received mutation request",
		zap.String("remoteAddr", r.RemoteAddr),
		zap.String("userAgent", r.UserAgent()))

	body, err := readRequestBody(r)
	if err != nil {
		logger.Error("Failed to read request body",
			zap.Error(err))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	logger.Info("Request body read successfully",
		zap.Int("bodySize", len(body)))

	var admissionReview admissionv1.AdmissionReview
	if err := json.Unmarshal(body, &admissionReview); err != nil {
		logger.Error("Failed to unmarshal admission review",
			zap.Error(err))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	req := admissionReview.Request
	if req == nil {
		logger.Error("AdmissionRequest is nil")
		http.Error(w, "AdmissionRequest is nil", http.StatusBadRequest)
		return
	}

	logger.Info("Processing admission review",
		zap.String("uid", string(req.UID)),
		zap.String("kind", req.Kind.Kind),
		zap.String("operation", string(req.Operation)),
		zap.String("namespace", req.Namespace))

	var pod corev1.Pod
	if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
		logger.Error("Failed to unmarshal pod object",
			zap.Error(err))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	logger.Info("Processing pod mutation",
		zap.String("namespace", pod.Namespace),
		zap.String("name", pod.Name))

	// Apply memory mutations
	patches := mutateMemoryResources(&pod)

	// Create admission response
	admissionResponse := &admissionv1.AdmissionResponse{
		UID:     req.UID,
		Allowed: true,
	}

	if len(patches) > 0 {
		patchBytes, err := json.Marshal(patches)
		if err != nil {
			logger.Error("Failed to marshal patches",
				zap.Error(err))
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		logger.Info("Generated JSON patch",
			zap.Int("patchSize", len(patchBytes)),
			zap.String("patch", string(patchBytes)))

		admissionResponse.Patch = patchBytes
		patchType := admissionv1.PatchTypeJSONPatch
		admissionResponse.PatchType = &patchType

		logger.Info("Applied memory patches successfully",
			zap.String("namespace", pod.Namespace),
			zap.String("name", pod.Name),
			zap.Int("patchCount", len(patches)))
	} else {
		logger.Info("No patches needed",
			zap.String("namespace", pod.Namespace),
			zap.String("name", pod.Name))
	}

	// Send response
	admissionReview.Response = admissionResponse
	responseBytes, err := json.Marshal(admissionReview)
	if err != nil {
		logger.Error("Failed to marshal admission review response",
			zap.Error(err))
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(responseBytes)

	logger.Info("Mutation request completed successfully",
		zap.String("namespace", pod.Namespace),
		zap.String("name", pod.Name),
		zap.Int("responseSize", len(responseBytes)))
}

func readRequestBody(r *http.Request) ([]byte, error) {
	if r.Body == nil {
		return nil, fmt.Errorf("request body is empty")
	}
	defer r.Body.Close()

	body, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read request body: %v", err)
	}

	return body, nil
}

func main() {
	defer logger.Sync() // Ensure all logs are flushed

	certPath := os.Getenv("TLS_CERT_FILE")
	keyPath := os.Getenv("TLS_KEY_FILE")
	port := os.Getenv("PORT")

	if certPath == "" {
		certPath = "/etc/certs/tls.crt"
	}
	if keyPath == "" {
		keyPath = "/etc/certs/tls.key"
	}
	if port == "" {
		port = "8443"
	}

	logger.Info("Starting memory webhook server",
		zap.String("version", "1.0.0"),
		zap.String("certPath", certPath),
		zap.String("keyPath", keyPath),
		zap.String("port", port))

	mux := http.NewServeMux()
	mux.HandleFunc("/mutate", (&WebhookServer{}).mutate)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
		logger.Info("Health check request",
			zap.String("remoteAddr", r.RemoteAddr))
	})

	server := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	logger.Info("Memory webhook server starting",
		zap.String("addr", ":"+port))

	if err := server.ListenAndServeTLS(certPath, keyPath); err != nil {
		logger.Error("Failed to start webhook server",
			zap.Error(err))
		os.Exit(1)
	}
}
