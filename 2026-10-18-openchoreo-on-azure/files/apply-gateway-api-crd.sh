#!/usr/bin/env bash
#
# Install the Gateway API CRDs. OpenChoreo's control-plane Gateway/HTTPRoute
# resources depend on these being present before kgateway and the control plane.
#
set -euo pipefail

: "${KUBECONFIG_FILE:?KUBECONFIG_FILE must be set}"
: "${GATEWAY_API_VERSION:?GATEWAY_API_VERSION must be set}"

export KUBECONFIG="${KUBECONFIG_FILE}"

# Server-side apply so re-runs reconcile instead of conflicting. Do not use
# --force: it deletes+creates the CRD and can evict the controller mid-flight.
kubectl apply --server-side \
  -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=${GATEWAY_API_VERSION}"
