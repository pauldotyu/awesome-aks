#!/usr/bin/env bash
#
# Create the OpenChoreo control-plane namespace (idempotent).
#
set -euo pipefail

: "${KUBECONFIG_FILE:?KUBECONFIG_FILE must be set}"
: "${OCP_NAMESPACE:?OCP_NAMESPACE must be set}"

export KUBECONFIG="${KUBECONFIG_FILE}"

echo "==> ensuring namespace ${OCP_NAMESPACE} exists"
kubectl create namespace "${OCP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
