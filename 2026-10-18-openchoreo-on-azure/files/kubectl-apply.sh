#!/usr/bin/env bash
#
# Apply a manifest and optionally wait for a resource condition.
#
# Used instead of the Kubernetes Terraform provider because the provider needs
# a live cluster connection at *plan* time, and the AKS cluster is created by
# this same apply. This is the pattern already used elsewhere in this repo
# (see 2023-10-19-build-ai-day-london/appconfig.tf).
#
# Environment:
#   KUBECONFIG_FILE  (required) path to the kubeconfig
#   MANIFEST_FILE    (required) manifest to apply
#   WAIT_KIND        (optional) kind to wait on, e.g. "certificate"
#   WAIT_NAME        (optional) name to wait on
#   WAIT_NAMESPACE   (optional) namespace of the resource
#   WAIT_CONDITION   (optional) condition type, default "Ready"
#   WAIT_TIMEOUT     (optional) default "300s"
#
set -euo pipefail

: "${KUBECONFIG_FILE:?KUBECONFIG_FILE must be set}"
: "${MANIFEST_FILE:?MANIFEST_FILE must be set}"

export KUBECONFIG="${KUBECONFIG_FILE}"

echo "==> applying ${MANIFEST_FILE}"
kubectl apply -f "${MANIFEST_FILE}"

if [ -n "${WAIT_KIND:-}" ] && [ -n "${WAIT_NAME:-}" ]; then
  condition="${WAIT_CONDITION:-Ready}"
  timeout="${WAIT_TIMEOUT:-300s}"
  ns_args=()
  if [ -n "${WAIT_NAMESPACE:-}" ]; then
    ns_args=(-n "${WAIT_NAMESPACE}")
  fi
  echo "==> waiting for ${WAIT_KIND}/${WAIT_NAME} to be ${condition}"
  kubectl wait --for="condition=${condition}" "${WAIT_KIND}/${WAIT_NAME}" \
    "${ns_args[@]}" --timeout="${timeout}"
fi
