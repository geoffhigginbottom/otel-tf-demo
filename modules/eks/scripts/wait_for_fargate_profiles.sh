#!/bin/bash
# Block until EKS Fargate profiles are ACTIVE (pods applied before this stay Pending forever).
set -euo pipefail

CLUSTER_NAME=${1:?cluster name required}
REGION=${2:?region required}
shift 2
PROFILES=("$@")

if [[ ${#PROFILES[@]} -eq 0 ]]; then
  echo "No Fargate profiles to wait for."
  exit 0
fi

for profile in "${PROFILES[@]}"; do
  echo "Waiting for Fargate profile ${profile} to become ACTIVE..."
  attempts=0
  max_attempts=60
  until [[ "$(aws eks describe-fargate-profile \
    --cluster-name "$CLUSTER_NAME" \
    --fargate-profile-name "$profile" \
    --region "$REGION" \
    --query 'fargateProfile.status' \
    --output text 2>/dev/null || echo "")" == "ACTIVE" ]]; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge $max_attempts ]]; then
      echo "ERROR: Fargate profile ${profile} not ACTIVE after $((max_attempts * 15))s"
      exit 1
    fi
    sleep 15
  done
  echo "Fargate profile ${profile} is ACTIVE."
done
