#!/usr/bin/env bash

set -veufo pipefail
cd "$(dirname "$0")"

tf_vars=(-var packet_token="${1:-$PACKET_TOKEN}" -var github_token="${2:-$GITHUB_TOKEN}" -var packet_ssh_key="${3:-$PACKET_SSH_KEY}" -var github_run_id="${GITHUB_RUN_ID:-}" -var git_author_name="${6:-$GIT_AUTHOR_NAME}" -var git_author_email="${7:-$GIT_AUTHOR_EMAIL}")

terraform init

function finish() {
    terraform destroy -auto-approve "${tf_vars[@]}"
}
trap finish EXIT

timeout 4h terraform apply -auto-approve "${tf_vars[@]}"
