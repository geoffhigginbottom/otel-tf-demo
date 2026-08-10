#!/bin/bash
# Register frontend-proxy Fargate pod IPs with an ALB target group (target_type=ip).
set -euo pipefail

TARGET_GROUP_ARN=$1
TARGET_PORT=$2
NAMESPACE=${3:-default}
LABEL_SELECTOR=${4:-opentelemetry.io/name=frontend-proxy}
MAX_ATTEMPTS=${5:-30}
SLEEP_SECONDS=${6:-10}

echo "Waiting for frontend-proxy pods in namespace ${NAMESPACE}..."
POD_IPS=""
for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  POD_IPS=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" \
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.status.podIP}{"\n"}{end}' \
    | sed '/^$/d' || true)

  if [[ -n "$POD_IPS" ]]; then
    break
  fi

  echo "Attempt ${attempt}/${MAX_ATTEMPTS}: no running pod IPs yet, retrying in ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

if [[ -z "$POD_IPS" ]]; then
  echo "No running frontend-proxy pod IPs found. Exiting."
  exit 1
fi

echo "Registering pod IP targets on port ${TARGET_PORT}..."
while IFS= read -r IP; do
  [[ -z "$IP" ]] && continue
  aws elbv2 register-targets \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets "Id=${IP},Port=${TARGET_PORT}" \
    --no-cli-pager
  echo "Registered ${IP}:${TARGET_PORT}"
done <<< "$POD_IPS"

echo "Deregistering stale targets..."
TG_TARGETS=$(aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query "TargetHealthDescriptions[*].Target.Id" \
  --output text \
  --no-cli-pager || true)

for ID in $TG_TARGETS; do
  if ! grep -qx "$ID" <<< "$POD_IPS"; then
    aws elbv2 deregister-targets \
      --target-group-arn "$TARGET_GROUP_ARN" \
      --targets "Id=${ID}" \
      --no-cli-pager
    echo "Deregistered stale target ${ID}"
  fi
done

echo
echo "Final target health status:"
aws elbv2 describe-target-health \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query "TargetHealthDescriptions[*].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State}" \
  --output table \
  --no-cli-pager || true

echo "Done."
