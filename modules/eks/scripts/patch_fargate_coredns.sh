#!/bin/bash
# CoreDNS is created before Fargate profiles finish; restart it so Fargate can schedule it.
set -euo pipefail

NAMESPACE=${1:-kube-system}
MAX_WAIT=${2:-300}

echo "=== Restarting CoreDNS for Fargate (${NAMESPACE}) ==="

if ! kubectl get deployment coredns -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "WARNING: deployment/coredns not found; skipping"
  exit 0
fi

kubectl rollout restart deployment/coredns -n "$NAMESPACE"
kubectl delete pod -n "$NAMESPACE" -l k8s-app=kube-dns --ignore-not-found --wait=false

echo "Waiting for CoreDNS to become ready..."
deadline=$((SECONDS + MAX_WAIT))
while true; do
  ready=$(kubectl get deployment coredns -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  desired=$(kubectl get deployment coredns -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "2")
  if [[ "${ready:-0}" -ge 1 && "${ready:-0}" -ge "${desired:-2}" ]]; then
    echo "CoreDNS ready (${ready}/${desired} replicas)."
    exit 0
  fi
  if (( SECONDS >= deadline )); then
    echo "WARNING: CoreDNS not fully ready after ${MAX_WAIT}s; continuing anyway"
    kubectl get pods -n "$NAMESPACE" -l k8s-app=kube-dns -o wide || true
    exit 0
  fi
  sleep 10
done
