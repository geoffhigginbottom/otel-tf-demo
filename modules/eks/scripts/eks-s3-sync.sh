#!/bin/bash
# Sync EKS deployment files between S3 and the admin server home directory.
#
# On the admin server (after terraform apply has populated S3):
#   eks-s3-sync pull          # download latest configs + scripts from S3
#   eks-s3-sync status        # show local vs S3 timestamps
#
# From your laptop (repo root, after editing files):
#   ./scripts/eks-s3-push.sh <bucket-name>
#   terraform apply           # also syncs when templates change
set -euo pipefail

ENV_FILE="${EKS_S3_ENV:-/home/ubuntu/eks-s3.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

HOME_DIR="${EKS_HOME:-/home/ubuntu}"
BUCKET="${S3_BUCKET:-}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
DRY_RUN="${DRY_RUN:-}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <pull|status>

  pull    Download EKS scripts, static YAML, and rendered Helm values from S3
          into ${HOME_DIR}/
  status  Show S3 prefixes and local file timestamps

Environment (set in ${ENV_FILE} or exported):
  S3_BUCKET    S3 bucket name (required)
  AWS_REGION   AWS region for S3 API calls
  EKS_HOME     Local destination directory (default: /home/ubuntu)

After pull, re-run workload steps as needed, e.g.:
  ./patch_fargate_workloads.sh
  kubectl apply -f splunk-astronomy-shop.yaml
EOF
}

require_bucket() {
  if [[ -z "$BUCKET" ]]; then
    echo "ERROR: S3_BUCKET is not set. Check ${ENV_FILE} or export S3_BUCKET." >&2
    exit 1
  fi
  if [[ -z "$REGION" ]]; then
    echo "ERROR: AWS_REGION is not set. Check ${ENV_FILE} or export AWS_REGION." >&2
    exit 1
  fi
}

aws_sync() {
  local src=$1
  local dst=$2
  shift 2
  local -a extra=("$@")
  local -a flags=(--region "$REGION")
  [[ -n "$DRY_RUN" ]] && flags+=(--dryrun)
  # shellcheck disable=SC2086
  aws s3 sync "$src" "$dst" "${flags[@]}" "${extra[@]}"
}

pull() {
  require_bucket
  echo "Pulling EKS files from s3://${BUCKET}/ into ${HOME_DIR}/"

  aws_sync "s3://${BUCKET}/scripts/eks/" "${HOME_DIR}/"
  aws_sync "s3://${BUCKET}/config_files/eks/" "${HOME_DIR}/" \
    --exclude '*.tpl' --exclude '*.ignore'
  aws_sync "s3://${BUCKET}/non_public_files/eks/" "${HOME_DIR}/"

  chmod +x "${HOME_DIR}"/*.sh 2>/dev/null || true
  echo "Pull complete."
  echo "Key files:"
  ls -la "${HOME_DIR}/"/*.sh "${HOME_DIR}/"/*.yaml 2>/dev/null | awk '{print "  " $9}' || true
}

status() {
  require_bucket
  echo "S3 bucket: s3://${BUCKET}/ (region ${REGION})"
  echo
  echo "=== scripts/eks/ ==="
  aws s3 ls "s3://${BUCKET}/scripts/eks/" --region "$REGION" || true
  echo
  echo "=== config_files/eks/ ==="
  aws s3 ls "s3://${BUCKET}/config_files/eks/" --region "$REGION" || true
  echo
  echo "=== non_public_files/eks/ ==="
  aws s3 ls "s3://${BUCKET}/non_public_files/eks/" --region "$REGION" || true
  echo
  echo "=== local ${HOME_DIR}/ ==="
  ls -la "${HOME_DIR}/"/*.sh "${HOME_DIR}/"/*.yaml 2>/dev/null || echo "  (no matching files)"
}

cmd=${1:-}
case "$cmd" in
  pull) pull ;;
  status) status ;;
  -h|--help|help|"") usage ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
