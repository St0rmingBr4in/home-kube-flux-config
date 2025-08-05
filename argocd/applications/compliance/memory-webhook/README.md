# Memory Webhook

A custom Go-based mutating admission webhook that ensures all Kubernetes pods have proper memory resource configuration for Guaranteed QoS.

## 🎯 What it does

This webhook automatically mutates pod resources to ensure **Guaranteed QoS** by:

1. **Dynamic field copying**: Sets memory request = memory limit (or vice versa)
2. **Default values**: Adds 512Mi memory resources if none exist
3. **Respects user values**: Preserves existing complete configurations

## 🔄 Mutation Logic

```yaml
# Case 1: User sets limit only
resources:
  limits:
    memory: 256Mi
# → Webhook adds: requests.memory: 256Mi

# Case 2: User sets request only  
resources:
  requests:
    memory: 128Mi
# → Webhook adds: limits.memory: 128Mi

# Case 3: User sets both with different values
resources:
  limits:
    memory: 512Mi
  requests:
    memory: 256Mi
# → Webhook sets: requests.memory: 512Mi (Guaranteed QoS)

# Case 4: No resources defined
# → Webhook adds both: limits=512Mi, requests=512Mi
```

## 🚀 Building and Deployment

### Prerequisites
- Docker for building the image
- cert-manager installed for TLS certificates
- ArgoCD for deployment

### Build the image
```bash
cd argocd/applications/memory-webhook
docker build -t memory-webhook:latest .
```