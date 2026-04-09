#!/usr/bin/env bash
# Dump cluster debug information. Always runs, even when earlier steps failed.
set -uo pipefail

echo "=== Test Summary ==="
echo "K3s cluster info:"
kubectl cluster-info

echo ""
echo "=== All pods ==="
kubectl get pods -A

echo ""
echo "=== ArgoCD Applications ==="
kubectl get applications -n argocd || echo "No applications found"

echo ""
echo "=== ArgoCD Applications Details ==="
kubectl describe applications -n argocd || echo "No applications found to describe"

echo ""
echo "=== ArgoCD Pod Status ==="
kubectl get pods -n argocd || echo "ArgoCD namespace not found"

echo ""
echo "=== ArgoCD Server Logs (last 50 lines) ==="
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50 \
  || echo "ArgoCD server logs not available"

echo ""
echo "=== ArgoCD Application Controller Logs (last 50 lines) ==="
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50 \
  || echo "ArgoCD application controller logs not available"

echo ""
echo "=== ArgoCD Repo Server Logs (last 50 lines) ==="
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50 \
  || echo "ArgoCD repo server logs not available"

echo ""
echo "=== ArgoCD Events ==="
kubectl get events -n argocd --sort-by='.lastTimestamp' || echo "No events found in argocd namespace"

echo ""
echo "=== Cluster Events (last 20) ==="
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20 || echo "No cluster events found"

echo ""
echo "=== Nodes ==="
kubectl get nodes

echo ""
echo "=== Node Conditions ==="
kubectl describe nodes || echo "Could not describe nodes"
