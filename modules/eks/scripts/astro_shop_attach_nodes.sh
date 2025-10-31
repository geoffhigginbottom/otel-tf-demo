#!/bin/bash
set -euo pipefail

CLUSTER_NAME=$1
NODEGROUP_NAME=$2
TARGET_GROUP_ARN=$3
TARGET_PORT=$4
AWS_REGION=$5

# Parse args
DEREGISTER=false
if [[ "${1:-}" == "--deregister" ]] || [[ "${1:-}" == "-d" ]]; then
  DEREGISTER=true
fi

echo "Fetching Auto Scaling Group..."
ASG_NAME=$(aws eks describe-nodegroup \
  --region "$AWS_REGION" \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "$NODEGROUP_NAME" \
  --query "nodegroup.resources.autoScalingGroups[0].name" \
  --output text)

if [[ -z "$ASG_NAME" || "$ASG_NAME" == "None" ]]; then
  echo "No ASG found. Exiting."
  exit 1
fi
echo "ASG: $ASG_NAME"

ASG_INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
  --region "$AWS_REGION" \
  --auto-scaling-group-names "$ASG_NAME" \
  --query "AutoScalingGroups[0].Instances[*].InstanceId" \
  --output text)

ASG_INSTANCE_LIST=($ASG_INSTANCES)

# Register missing targets
for ID in "${ASG_INSTANCE_LIST[@]}"; do
  aws elbv2 register-targets \
    --region "$AWS_REGION" \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets "Id=$ID,Port=$TARGET_PORT" \
    --no-cli-pager
done

if [[ "$DEREGISTER" == true ]]; then
  echo "Deregistering stale targets..."
  TG_TARGETS=$(aws elbv2 describe-target-health \
    --region "$AWS_REGION" \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --query "TargetHealthDescriptions[*].Target.Id" \
    --output text --cli-read-timeout 5 --no-cli-pager || true)
  TG_TARGET_LIST=($TG_TARGETS)

  for ID in "${TG_TARGET_LIST[@]}"; do
    if [[ ! " ${ASG_INSTANCE_LIST[*]} " =~ " ${ID} " ]]; then
      aws elbv2 deregister-targets \
        --region "$AWS_REGION" \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --targets "Id=$ID" \
        --no-cli-pager
    fi
  done
else
  echo "Skipping deregistration (use --deregister to remove stale targets)"
fi

echo
echo "Sync complete ✅"
echo "Final target health status (once, no wait):"
aws elbv2 describe-target-health \
  --region "$AWS_REGION" \
  --target-group-arn "$TARGET_GROUP_ARN" \
  --query "TargetHealthDescriptions[*].{Instance:Target.Id,State:TargetHealth.State}" \
  --output table \
  --cli-read-timeout 5 \
  --no-cli-pager || true

echo "Done."
exit 0

