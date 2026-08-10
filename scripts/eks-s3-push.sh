#!/bin/bash
# Push EKS deployment files from this repo to S3 (run from repo root on your laptop).
#
# Usage:
#   ./scripts/eks-s3-push.sh <s3-bucket-name>
#   S3_BUCKET=my-bucket ./scripts/eks-s3-push.sh
#
# Rendered Helm values (non_public_files/eks/) require secrets/tokens from terraform.
# Run `terraform apply` first if templates changed, or push will skip missing rendered files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUCKET="${1:-${S3_BUCKET:-}}"

if [[ -z "$BUCKET" ]]; then
  echo "Usage: $0 <s3-bucket-name>" >&2
  echo "   or: S3_BUCKET=my-bucket $0" >&2
  exit 1
fi

echo "Pushing EKS files to s3://${BUCKET}/"

aws s3 sync "${ROOT}/modules/eks/scripts/" "s3://${BUCKET}/scripts/eks/" --delete

aws s3 sync "${ROOT}/config_files/eks/" "s3://${BUCKET}/config_files/eks/" \
  --delete --exclude '*.tpl' --exclude '*.ignore'

if [[ -d "${ROOT}/non_public_files/eks" ]] && [[ -n "$(ls -A "${ROOT}/non_public_files/eks" 2>/dev/null || true)" ]]; then
  aws s3 sync "${ROOT}/non_public_files/eks/" "s3://${BUCKET}/non_public_files/eks/" --delete
else
  echo "WARN: non_public_files/eks/ is empty or missing."
  echo "      Run 'terraform apply' to render secrets/Helm values, then re-run this script."
fi

echo "Push complete."
echo "On the admin server, run:  eks-s3-sync pull"
