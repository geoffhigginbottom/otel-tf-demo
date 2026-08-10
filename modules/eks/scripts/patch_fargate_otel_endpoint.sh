#!/bin/bash
# Point Astronomy Shop workloads at the Splunk OTel collector service (Fargate has no node-local agent).
# Also inject k8s pod metadata into OTEL_RESOURCE_ATTRIBUTES so gateway k8s_attributes can correlate
# traces with Infrastructure Monitoring (ClusterIP SNAT hides pod IPs from connection-based association).
set -euo pipefail

NAMESPACE=${1:-default}
COLLECTOR_HOST=${2:-splunk-otel-collector}
FRONTEND_DEPLOYMENT=${3:-frontend-proxy}
CLUSTER_NAME=${4:-}

if [[ -z "$CLUSTER_NAME" && -f /home/ubuntu/eks_cluster_name ]]; then
  CLUSTER_NAME=$(cat /home/ubuntu/eks_cluster_name)
fi

K8S_RESOURCE_SUFFIX='k8s.pod.name=$(K8S_POD_NAME),k8s.pod.uid=$(K8S_POD_UID),k8s.namespace.name=$(K8S_NAMESPACE),k8s.node.name=$(K8S_NODE_NAME)'
if [[ -n "$CLUSTER_NAME" ]]; then
  K8S_RESOURCE_SUFFIX="k8s.cluster.name=${CLUSTER_NAME},${K8S_RESOURCE_SUFFIX}"
fi

k8s_downward_env_json='[
  {"name": "K8S_POD_NAME", "valueFrom": {"fieldRef": {"fieldPath": "metadata.name"}}},
  {"name": "K8S_POD_UID", "valueFrom": {"fieldRef": {"fieldPath": "metadata.uid"}}},
  {"name": "K8S_NAMESPACE", "valueFrom": {"fieldRef": {"fieldPath": "metadata.namespace"}}},
  {"name": "K8S_NODE_NAME", "valueFrom": {"fieldRef": {"fieldPath": "spec.nodeName"}}}
]'

patch_k8s_downward_env() {
  local deployment=$1
  local container_index=$2

  if kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[*].name}" \
    | tr ' ' '\n' | grep -qx 'K8S_POD_UID'; then
    return 0
  fi

  # Insert after OTEL_SERVICE_NAME when present so kubelet can expand $(K8S_*) inside
  # OTEL_RESOURCE_ATTRIBUTES (referenced vars must appear earlier in the env list).
  local insert_at=0
  if kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='OTEL_SERVICE_NAME')].name}" \
    | grep -qx 'OTEL_SERVICE_NAME'; then
    insert_at=1
  fi

  kubectl patch "deployment/${deployment}" -n "$NAMESPACE" --type=json -p="[
    {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/${container_index}/env/${insert_at}\", \"value\": {\"name\": \"K8S_POD_NAME\", \"valueFrom\": {\"fieldRef\": {\"fieldPath\": \"metadata.name\"}}}},
    {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/${container_index}/env/$((insert_at + 1))\", \"value\": {\"name\": \"K8S_POD_UID\", \"valueFrom\": {\"fieldRef\": {\"fieldPath\": \"metadata.uid\"}}}},
    {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/${container_index}/env/$((insert_at + 2))\", \"value\": {\"name\": \"K8S_NAMESPACE\", \"valueFrom\": {\"fieldRef\": {\"fieldPath\": \"metadata.namespace\"}}}},
    {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/${container_index}/env/$((insert_at + 3))\", \"value\": {\"name\": \"K8S_NODE_NAME\", \"valueFrom\": {\"fieldRef\": {\"fieldPath\": \"spec.nodeName\"}}}}
  ]" >/dev/null
}

# Kubelet only expands $(VAR) when VAR is defined earlier in the same container env list.
reorder_otel_container_env() {
  local deployment=$1
  local container_index=$2
  local otel_attrs reordered

  otel_attrs=$(kubectl get deployment "$deployment" -n "$NAMESPACE" \
    -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='OTEL_RESOURCE_ATTRIBUTES')].value}" 2>/dev/null || true)
  [[ -z "$otel_attrs" || "$otel_attrs" != *'$(K8S_'* ]] && return 0

  reordered=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o json | jq -c --argjson idx "$container_index" --argjson k8s "$k8s_downward_env_json" '
    def k8s_names: ["K8S_POD_NAME", "K8S_POD_UID", "K8S_NAMESPACE", "K8S_NODE_NAME"];
    def without($names):
      map(select(.name as $n | ($names | index($n)) | not));
    .spec.template.spec.containers[$idx].env as $env |
    (reduce ($env + $k8s)[] as $e ({}; .[$e.name] = $e) | [.[]]) as $uniq |
    ($uniq | map(select(.name == "OTEL_SERVICE_NAME"))) as $otel_svc |
    ($uniq | map(select(.name as $n | k8s_names | index($n)))) as $k8s |
    ($uniq | map(select(.name == "NODE_IP"))) as $node_ip |
    ($uniq | map(select(.name == "OTEL_COLLECTOR_NAME" or .name == "OTEL_COLLECTOR_HOST"))) as $collector |
    ($uniq | map(select(.name == "OTEL_RESOURCE_ATTRIBUTES"))) as $resource |
    ($uniq
      | without(["OTEL_SERVICE_NAME"] + k8s_names + ["NODE_IP", "OTEL_COLLECTOR_NAME", "OTEL_COLLECTOR_HOST", "OTEL_RESOURCE_ATTRIBUTES"])
    ) as $middle |
    ($otel_svc + $k8s + $node_ip + $collector + $middle + $resource)
  ')

  kubectl patch "deployment/${deployment}" -n "$NAMESPACE" --type=json \
    -p="[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/${container_index}/env\",\"value\":${reordered}}]" >/dev/null
}

patch_otel_resource_attributes() {
  local deployment=$1
  local container_index=$2
  local current new

  current=$(kubectl get deployment "$deployment" -n "$NAMESPACE" \
    -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='OTEL_RESOURCE_ATTRIBUTES')].value}" 2>/dev/null || true)

  if [[ -z "$current" ]]; then
    return 0
  fi
  if [[ "$current" == *'k8s.pod.uid'* ]]; then
    return 0
  fi

  new="${current},${K8S_RESOURCE_SUFFIX}"
  kubectl set env "deployment/${deployment}" -n "$NAMESPACE" \
    "OTEL_RESOURCE_ATTRIBUTES=${new}" --containers="$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].name}")" \
    --overwrite >/dev/null
}

patch_profiler_logs_endpoint() {
  local deployment=$1
  local container_index=$2
  local container_name otlp_endpoint has_profiler has_logs_endpoint has_node_metrics

  container_name=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].name}")
  has_logs_endpoint=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='SPLUNK_PROFILER_LOGS_ENDPOINT')].name}" 2>/dev/null || true)
  [[ -n "$has_logs_endpoint" ]] && return 0

  has_node_metrics=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='SPLUNK_INSTRUMENTATION_METRICS_ENABLED')].value}" 2>/dev/null || true)
  [[ -n "$has_node_metrics" ]] && return 0

  has_profiler=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='SPLUNK_PROFILER_ENABLED')].value}" 2>/dev/null || true)
  otlp_endpoint=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='OTEL_EXPORTER_OTLP_ENDPOINT')].value}" 2>/dev/null || true)
  [[ -z "$otlp_endpoint" && "$has_profiler" != "true" ]] && return 0

  # .NET/Java profiler logs; Node.js uses SPLUNK_AUTOMATIC_LOG_COLLECTION instead.
  kubectl set env "deployment/${deployment}" -n "$NAMESPACE" \
    "SPLUNK_PROFILER_LOGS_ENDPOINT=http://\$(OTEL_COLLECTOR_NAME):4318/v1/logs" \
    --containers="${container_name}" --overwrite >/dev/null
}

patch_automatic_log_collection() {
  local deployment=$1
  local container_index=$2
  local container_name otlp_endpoint has_metrics has_profiler has_auto_logs has_otlp_logs java_tool_options

  container_name=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].name}")
  has_auto_logs=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='SPLUNK_AUTOMATIC_LOG_COLLECTION')].name}" 2>/dev/null || true)
  [[ -n "$has_auto_logs" ]] && return 0

  java_tool_options=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='JAVA_TOOL_OPTIONS')].name}" 2>/dev/null || true)
  [[ -n "$java_tool_options" ]] && return 0

  otlp_endpoint=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='OTEL_EXPORTER_OTLP_ENDPOINT')].value}" 2>/dev/null || true)
  has_metrics=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='SPLUNK_INSTRUMENTATION_METRICS_ENABLED')].value}" 2>/dev/null || true)
  has_profiler=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${container_index}].env[?(@.name=='SPLUNK_PROFILER_ENABLED')].value}" 2>/dev/null || true)
  [[ -z "$otlp_endpoint" && "$has_metrics" != "true" && "$has_profiler" != "true" ]] && return 0
  [[ -z "$has_metrics" && "$has_profiler" != "true" ]] && return 0

  # Node.js Splunk OTel: pino instrumentation sends logs via OTLP only when enabled.
  kubectl set env "deployment/${deployment}" -n "$NAMESPACE" \
    "SPLUNK_AUTOMATIC_LOG_COLLECTION=true" \
    "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://\$(OTEL_COLLECTOR_NAME):4318/v1/logs" \
    --containers="${container_name}" --overwrite >/dev/null
}

echo "Patching OTEL collector endpoint to ${COLLECTOR_HOST} for deployments in ${NAMESPACE}..."

mapfile -t DEPLOYMENTS < <(kubectl get deploy -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

if [[ ${#DEPLOYMENTS[@]} -eq 0 ]]; then
  echo "No deployments found in namespace ${NAMESPACE}."
  exit 1
fi

for deployment in "${DEPLOYMENTS[@]}"; do
  [[ -z "$deployment" ]] && continue
  [[ "$deployment" == splunk-otel-collector* ]] && continue

  container_count=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[*].name}' | wc -w | tr -d ' ')
  updated=false

  for ((i = 0; i < container_count; i++)); do
    container_name=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${i}].name}")
    has_otel=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath="{.spec.template.spec.containers[${i}].env[?(@.name=='OTEL_COLLECTOR_NAME')].name}" 2>/dev/null || true)
    [[ -z "$has_otel" ]] && continue

    if kubectl set env "deployment/${deployment}" -n "$NAMESPACE" \
      OTEL_COLLECTOR_NAME="${COLLECTOR_HOST}" \
      OTEL_COLLECTOR_HOST="${COLLECTOR_HOST}" \
      --containers="${container_name}" \
      --overwrite >/dev/null 2>&1; then
      updated=true
    fi
    patch_k8s_downward_env "$deployment" "$i"
    patch_otel_resource_attributes "$deployment" "$i"
    reorder_otel_container_env "$deployment" "$i"
    patch_profiler_logs_endpoint "$deployment" "$i"
    patch_automatic_log_collection "$deployment" "$i"
    updated=true
  done

  if [[ "$updated" == true ]]; then
    echo "Updated ${deployment} (collector endpoint + k8s resource attributes + logs export)"
  else
    echo "Skipped ${deployment} (no OTEL-enabled containers)"
  fi
done

echo "Switching ${FRONTEND_DEPLOYMENT} service to ClusterIP..."
kubectl patch "service/${FRONTEND_DEPLOYMENT}" -n "$NAMESPACE" --type merge -p "$(cat <<EOF
{
  "spec": {
    "type": "ClusterIP",
    "ports": [
      {
        "name": "tcp-service",
        "port": 8080,
        "targetPort": 8080,
        "protocol": "TCP"
      }
    ]
  }
}
EOF
)"

echo "Waiting for ${FRONTEND_DEPLOYMENT} rollout..."
kubectl rollout status "deployment/${FRONTEND_DEPLOYMENT}" -n "$NAMESPACE" --timeout=600s

echo "Fargate OTEL endpoint patch complete."
