#!/bin/bash
# Apply Fargate-specific fixes after the Astronomy Shop manifest is deployed.
set -euo pipefail

NAMESPACE=${1:-default}
COLLECTOR_HOST=${2:-splunk-otel-collector}
OVERRIDES_FILE=${3:-/home/ubuntu/fargate-overrides.yaml}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/patch_fargate_coredns.sh"

echo "Recycling Pending pods created before the Fargate profile was active..."
kubectl delete pods -n "$NAMESPACE" --field-selector=status.phase=Pending --ignore-not-found --wait=false || true

echo "=== Fargate workload patches (${NAMESPACE}) ==="

get_volume_index() {
  local deployment=$1
  local volume_name=$2
  local i=0
  local name

  while name=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.volumes[$i].name}" 2>/dev/null); do
    [[ -z "$name" ]] && break
    if [[ "$name" == "$volume_name" ]]; then
      echo "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

replace_pvc_volume_with_emptydir() {
  local deployment=$1
  local volume_name=$2
  local idx

  if ! idx=$(get_volume_index "$deployment" "$volume_name"); then
    echo "WARNING: volume ${volume_name} not found on deployment/${deployment}; skipping"
    return 0
  fi

  kubectl patch deployment "$deployment" -n "$NAMESPACE" --type=json -p="[
    {\"op\": \"replace\", \"path\": \"/spec/template/spec/volumes/${idx}\", \"value\": {\"name\": \"${volume_name}\", \"emptyDir\": {}}}
  ]"
}

patch_flagd_deployments() {
  if ! kubectl get deployment flagd -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "WARNING: deployment/flagd not found; skipping flagd patches"
    return 0
  fi

  echo "Patching flagd volumes (PVC -> emptyDir)..."
  replace_pvc_volume_with_emptydir flagd config-rw

  if ! kubectl get deployment flagd-ui -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "WARNING: deployment/flagd-ui not found; skipping flagd-ui patches"
    return 0
  fi

  echo "Patching flagd-ui volumes (PVC -> emptyDir) and removing podAffinity..."
  replace_pvc_volume_with_emptydir flagd-ui config-rw
  kubectl patch deployment flagd-ui -n "$NAMESPACE" --type=json \
    -p='[{"op": "remove", "path": "/spec/template/spec/affinity"}]' \
    2>/dev/null || true
}

patch_flagd_deployments

echo "Replacing sql-server-fraud StatefulSet (EBS PVC) with Deployment (emptyDir)..."
kubectl delete statefulset sql-server-fraud -n "$NAMESPACE" --ignore-not-found --wait=true --timeout=180s || true
kubectl delete pod -n "$NAMESPACE" -l app=sql-server-fraud --ignore-not-found --wait=true --timeout=120s || true

if [[ -f "$OVERRIDES_FILE" ]]; then
  echo "Applying ${OVERRIDES_FILE}..."
  kubectl apply -f "$OVERRIDES_FILE"
else
  echo "WARNING: ${OVERRIDES_FILE} not found; skipping sql-server-fraud deployment"
fi

echo "Removing unused EBS PVCs..."
kubectl delete pvc flagd-shared-config -n "$NAMESPACE" --ignore-not-found --wait=false || true
kubectl delete pvc -n "$NAMESPACE" -l app=sql-server-fraud --ignore-not-found --wait=false || true
for pvc in $(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep '^data-sql-server-fraud' || true); do
  kubectl delete pvc "$pvc" -n "$NAMESPACE" --ignore-not-found --wait=false || true
done

echo "Waiting for core dependencies..."
for dep in flagd flagd-ui sql-server-fraud kafka postgresql valkey-cart; do
  if kubectl get deployment "$dep" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl rollout status "deployment/${dep}" -n "$NAMESPACE" --timeout=600s || true
  fi
done

"${SCRIPT_DIR}/patch_fargate_otel_endpoint.sh" "$NAMESPACE" "$COLLECTOR_HOST" frontend-proxy

echo "Restarting workloads stuck in Init while CoreDNS was unavailable..."
for dep in accounting cart checkout fraud-detection shop-dc-load-generator; do
  if kubectl get deployment "$dep" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl rollout restart "deployment/${dep}" -n "$NAMESPACE" || true
  fi
done

echo "Fargate workload patch complete."
