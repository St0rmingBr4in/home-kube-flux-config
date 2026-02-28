package main

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func createTestPod(name string, containerResources *corev1.ResourceRequirements) *corev1.Pod {
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: "test",
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "test-container",
					Image: "nginx:alpine",
				},
			},
		},
	}

	if containerResources != nil {
		pod.Spec.Containers[0].Resources = *containerResources
	}

	return pod
}

func createResourceRequirements(limitMem, requestMem string) *corev1.ResourceRequirements {
	resources := &corev1.ResourceRequirements{}

	if limitMem != "" {
		if resources.Limits == nil {
			resources.Limits = corev1.ResourceList{}
		}
		resources.Limits[corev1.ResourceMemory] = resource.MustParse(limitMem)
	}

	if requestMem != "" {
		if resources.Requests == nil {
			resources.Requests = corev1.ResourceList{}
		}
		resources.Requests[corev1.ResourceMemory] = resource.MustParse(requestMem)
	}

	return resources
}

func TestMutateMemoryResources_NoResourcesDefined(t *testing.T) {
	pod := createTestPod("test-pod", nil)

	patches := mutateMemoryResources(pod)

	require.Len(t, patches, 1, "Expected exactly 1 patch for pod with no resources")

	expectedPatch := patchOperation{
		Op:   "add",
		Path: "/spec/containers/0/resources",
		Value: map[string]interface{}{
			"limits": map[string]interface{}{
				"memory": "512Mi",
			},
			"requests": map[string]interface{}{
				"memory": "512Mi",
			},
		},
	}

	require.Equal(t, expectedPatch, patches[0], "Patch should add complete resources block with default memory")
}

func TestMutateMemoryResources_OnlyLimitSet(t *testing.T) {
	resources := createResourceRequirements("1Gi", "")
	pod := createTestPod("test-pod", resources)

	patches := mutateMemoryResources(pod)

	require.Len(t, patches, 1, "Expected exactly 1 patch for pod with only limit set")

	expectedPatch := patchOperation{
		Op:   "add",
		Path: "/spec/containers/0/resources/requests",
		Value: map[string]interface{}{
			"memory": "1Gi",
		},
	}

	require.Equal(t, expectedPatch, patches[0], "Patch should add requests block to match limit")
}

func TestMutateMemoryResources_OnlyRequestSet(t *testing.T) {
	resources := createResourceRequirements("", "256Mi")
	pod := createTestPod("test-pod", resources)

	patches := mutateMemoryResources(pod)

	require.Len(t, patches, 1, "Expected exactly 1 patch for pod with only request set")

	expectedPatch := patchOperation{
		Op:   "add",
		Path: "/spec/containers/0/resources/limits",
		Value: map[string]interface{}{
			"memory": "256Mi",
		},
	}

	require.Equal(t, expectedPatch, patches[0], "Patch should add limits block to match request")
}

func TestMutateMemoryResources_BothSetButDifferent(t *testing.T) {
	resources := createResourceRequirements("2Gi", "1Gi")
	pod := createTestPod("test-pod", resources)

	patches := mutateMemoryResources(pod)

	require.Len(t, patches, 1, "Expected exactly 1 patch for pod with different limit and request")

	expectedPatch := patchOperation{
		Op:    "replace",
		Path:  "/spec/containers/0/resources/requests/memory",
		Value: "2Gi",
	}

	require.Equal(t, expectedPatch, patches[0], "Patch should replace request to match limit for Guaranteed QoS")
}

func TestMutateMemoryResources_BothSetAndEqual(t *testing.T) {
	resources := createResourceRequirements("1Gi", "1Gi")
	pod := createTestPod("test-pod", resources)

	patches := mutateMemoryResources(pod)

	require.Empty(t, patches, "No patches should be needed when memory limit and request are already equal")
}

func TestMutateMemoryResources_WithInitContainers(t *testing.T) {
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-pod",
			Namespace: "test",
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "main-container",
					Image: "nginx:alpine",
				},
			},
			InitContainers: []corev1.Container{
				{
					Name:      "init-container",
					Image:     "busybox",
					Resources: *createResourceRequirements("512Mi", ""),
				},
			},
		},
	}

	patches := mutateMemoryResources(pod)

	require.Len(t, patches, 2, "Expected 2 patches: one for main container, one for init container")

	expectedMainPatch := patchOperation{
		Op:   "add",
		Path: "/spec/containers/0/resources",
		Value: map[string]interface{}{
			"limits": map[string]interface{}{
				"memory": "512Mi",
			},
			"requests": map[string]interface{}{
				"memory": "512Mi",
			},
		},
	}

	expectedInitPatch := patchOperation{
		Op:   "add",
		Path: "/spec/initContainers/0/resources/requests",
		Value: map[string]interface{}{
			"memory": "512Mi",
		},
	}

	require.Equal(t, expectedMainPatch, patches[0], "First patch should add complete resources to main container")
	require.Equal(t, expectedInitPatch, patches[1], "Second patch should add requests to init container")
}

func TestMutateContainerMemory_EmptyResources(t *testing.T) {
	container := corev1.Container{
		Name:  "test",
		Image: "nginx",
		Resources: corev1.ResourceRequirements{
			Limits:   corev1.ResourceList{},
			Requests: corev1.ResourceList{},
		},
	}

	patches := mutateContainerMemory(container, "/spec/containers/0/resources")

	require.Len(t, patches, 2, "Expected 2 patches for container with empty resource lists")

	expectedPatches := []patchOperation{
		{
			Op:    "add",
			Path:  "/spec/containers/0/resources/limits/memory",
			Value: "512Mi",
		},
		{
			Op:    "add",
			Path:  "/spec/containers/0/resources/requests/memory",
			Value: "512Mi",
		},
	}

	require.Equal(t, expectedPatches[0], patches[0], "First patch should add memory limit")
	require.Equal(t, expectedPatches[1], patches[1], "Second patch should add memory request")
}

func TestMutateContainerMemory_WithCPUOnly(t *testing.T) {
	container := corev1.Container{
		Name:  "test",
		Image: "nginx",
		Resources: corev1.ResourceRequirements{
			Limits: corev1.ResourceList{
				corev1.ResourceCPU: resource.MustParse("500m"),
			},
			Requests: corev1.ResourceList{
				corev1.ResourceCPU: resource.MustParse("100m"),
			},
		},
	}

	patches := mutateContainerMemory(container, "/spec/containers/0/resources")

	require.Len(t, patches, 2, "Expected 2 patches to add memory while preserving CPU resources")

	expectedPatches := []patchOperation{
		{
			Op:    "add",
			Path:  "/spec/containers/0/resources/limits/memory",
			Value: "512Mi",
		},
		{
			Op:    "add",
			Path:  "/spec/containers/0/resources/requests/memory",
			Value: "512Mi",
		},
	}

	require.Equal(t, expectedPatches[0], patches[0], "First patch should add memory limit")
	require.Equal(t, expectedPatches[1], patches[1], "Second patch should add memory request")
}

func TestMutateContainerMemory_NilResourceObjects(t *testing.T) {
	container := corev1.Container{
		Name:  "test",
		Image: "nginx",
		Resources: corev1.ResourceRequirements{
			Limits: nil,
			Requests: corev1.ResourceList{
				corev1.ResourceMemory: resource.MustParse("128Mi"),
			},
		},
	}

	patches := mutateContainerMemory(container, "/spec/containers/0/resources")

	require.Len(t, patches, 1, "Expected 1 patch to add limits block")

	expectedPatch := patchOperation{
		Op:   "add",
		Path: "/spec/containers/0/resources/limits",
		Value: map[string]interface{}{
			"memory": "128Mi",
		},
	}

	require.Equal(t, expectedPatch, patches[0], "Patch should add limits block to match request")
}

func TestPatchOperationJSONMarshaling(t *testing.T) {
	patch := patchOperation{
		Op:   "add",
		Path: "/spec/containers/0/resources",
		Value: map[string]interface{}{
			"limits": map[string]interface{}{
				"memory": "512Mi",
			},
			"requests": map[string]interface{}{
				"memory": "512Mi",
			},
		},
	}

	jsonBytes, err := json.Marshal([]patchOperation{patch})
	require.NoError(t, err, "Should be able to marshal patch to JSON")

	expectedJSON := `[{"op":"add","path":"/spec/containers/0/resources","value":{"limits":{"memory":"512Mi"},"requests":{"memory":"512Mi"}}}]`
	require.JSONEq(t, expectedJSON, string(jsonBytes), "JSON should match expected format")
}

func TestMutateMemoryResources_MultipleContainers(t *testing.T) {
	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "multi-container-pod",
			Namespace: "test",
		},
		Spec: corev1.PodSpec{
			Containers: []corev1.Container{
				{
					Name:  "no-resources",
					Image: "nginx:alpine",
				},
				{
					Name:      "limit-only",
					Image:     "redis:alpine",
					Resources: *createResourceRequirements("1Gi", ""),
				},
				{
					Name:      "request-only",
					Image:     "postgres:alpine",
					Resources: *createResourceRequirements("", "512Mi"),
				},
			},
		},
	}

	patches := mutateMemoryResources(pod)

	require.Len(t, patches, 3, "Expected 3 patches for 3 containers with different resource configurations")

	require.Equal(t, "add", patches[0].Op, "First container should get add operation")
	require.Equal(t, "/spec/containers/0/resources", patches[0].Path, "First patch should target container 0")

	require.Equal(t, "add", patches[1].Op, "Second container should get add operation")
	require.Equal(t, "/spec/containers/1/resources/requests", patches[1].Path, "Second patch should add requests")

	require.Equal(t, "add", patches[2].Op, "Third container should get add operation")
	require.Equal(t, "/spec/containers/2/resources/limits", patches[2].Path, "Third patch should add limits")
}

func BenchmarkMutateMemoryResources(b *testing.B) {
	pod := createTestPod("benchmark-pod", nil)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		mutateMemoryResources(pod)
	}
}

func BenchmarkMutateContainerMemory(b *testing.B) {
	container := corev1.Container{
		Name:  "test",
		Image: "nginx",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		mutateContainerMemory(container, "/spec/containers/0/resources")
	}
}
