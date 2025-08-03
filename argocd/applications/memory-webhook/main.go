package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
)

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

	// Process regular containers
	for i, container := range pod.Spec.Containers {
		containerPatches := mutateContainerMemory(container, fmt.Sprintf("/spec/containers/%d/resources", i))
		patches = append(patches, containerPatches...)
	}

	// Process init containers
	for i, container := range pod.Spec.InitContainers {
		containerPatches := mutateContainerMemory(container, fmt.Sprintf("/spec/initContainers/%d/resources", i))
		patches = append(patches, containerPatches...)
	}

	return patches
}

func mutateContainerMemory(container corev1.Container, basePath string) []patchOperation {
	var patches []patchOperation
	defaultMemory := "512Mi"

	// Initialize resources if nil
	if container.Resources.Limits == nil && container.Resources.Requests == nil {
		// Case 1: No resources defined - add both limit and request
		patches = append(patches, patchOperation{
			Op:   "add",
			Path: basePath,
			Value: map[string]interface{}{
				"limits": map[string]string{
					"memory": defaultMemory,
				},
				"requests": map[string]string{
					"memory": defaultMemory,
				},
			},
		})
		return patches
	}

	// Ensure limits exists
	if container.Resources.Limits == nil {
		patches = append(patches, patchOperation{
			Op:    "add",
			Path:  basePath + "/limits",
			Value: map[string]string{},
		})
	}

	// Ensure requests exists
	if container.Resources.Requests == nil {
		patches = append(patches, patchOperation{
			Op:    "add",
			Path:  basePath + "/requests",
			Value: map[string]string{},
		})
	}

	// Get current memory values
	memoryLimit := container.Resources.Limits[corev1.ResourceMemory]
	memoryRequest := container.Resources.Requests[corev1.ResourceMemory]

	hasLimit := !memoryLimit.IsZero()
	hasRequest := !memoryRequest.IsZero()

	if hasLimit && hasRequest {
		// Case 2: Both exist - make request = limit for Guaranteed QoS
		patches = append(patches, patchOperation{
			Op:    "replace",
			Path:  basePath + "/requests/memory",
			Value: memoryLimit.String(),
		})
	} else if hasLimit && !hasRequest {
		// Case 3: Only limit exists - set request = limit
		patches = append(patches, patchOperation{
			Op:    "add",
			Path:  basePath + "/requests/memory",
			Value: memoryLimit.String(),
		})
	} else if !hasLimit && hasRequest {
		// Case 4: Only request exists - set limit = request
		patches = append(patches, patchOperation{
			Op:    "add",
			Path:  basePath + "/limits/memory",
			Value: memoryRequest.String(),
		})
	} else {
		// Case 5: Neither exists - add defaults
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
	}

	return patches
}

// Main mutation handler
func (ws *WebhookServer) mutate(w http.ResponseWriter, r *http.Request) {
	log.Println("Handling mutation request")

	body, err := readRequestBody(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var admissionReview admissionv1.AdmissionReview
	if err := json.Unmarshal(body, &admissionReview); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	req := admissionReview.Request
	var pod corev1.Pod

	if err := json.Unmarshal(req.Object.Raw, &pod); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Mutating pod: %s/%s", pod.Namespace, pod.Name)

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
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		admissionResponse.Patch = patchBytes
		patchType := admissionv1.PatchTypeJSONPatch
		admissionResponse.PatchType = &patchType

		log.Printf("Applied %d patches to pod %s/%s", len(patches), pod.Namespace, pod.Name)
	}

	// Send response
	admissionReview.Response = admissionResponse
	responseBytes, err := json.Marshal(admissionReview)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(responseBytes)
}

func readRequestBody(r *http.Request) ([]byte, error) {
	if r.Body == nil {
		return nil, fmt.Errorf("request body is empty")
	}

	body := make([]byte, r.ContentLength)
	if _, err := r.Body.Read(body); err != nil {
		return nil, fmt.Errorf("failed to read request body: %v", err)
	}

	return body, nil
}

func main() {
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

	mux := http.NewServeMux()
	mux.HandleFunc("/mutate", (&WebhookServer{}).mutate)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	server := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	log.Printf("Starting webhook server on port %s", port)
	log.Printf("Using TLS cert: %s, key: %s", certPath, keyPath)

	if err := server.ListenAndServeTLS(certPath, keyPath); err != nil {
		log.Fatalf("Failed to start webhook server: %v", err)
	}
}
