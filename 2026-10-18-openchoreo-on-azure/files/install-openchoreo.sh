#!/usr/bin/env bash
#
# Install the OpenChoreo control plane only after every prerequisite is ready:
#   1. the cp-gateway-tls Certificate is Ready (cert-manager finished DNS-01),
#   2. the backstage-secrets Secret is materialized by ESO with all four keys,
#   3. the control plane renders and its pods become available.
#
# The heavy lifting (CRDs, k8s namespace, kgateway, issuers, certificate, secret)
# is already done by Terraform-managed Helm/kubernetes resources; this step waits
# for the *runtime* readiness conditions Terraform cannot observe and runs the
# release with the generated values file.
#
set -euo pipefail

: "${KUBECONFIG_FILE:?KUBECONFIG_FILE must be set}"
: "${OCP_NAMESPACE:?OCP_NAMESPACE must be set}"
: "${OCP_VALUES_FILE:?OCP_VALUES_FILE must be set}"
: "${OPENCHOREO_VERSION:?OPENCHOREO_VERSION must be set}"

export KUBECONFIG="${KUBECONFIG_FILE}"
ns="${OCP_NAMESPACE}"

echo "==> waiting for cp-gateway-tls to be Ready (DNS-01 validated by cert-manager)"
kubectl wait --for=condition=Ready certificate/cp-gateway-tls -n "${ns}" --timeout=600s

echo "==> waiting for ESO to materialize backstage-secrets with all four keys"
attempt=0
while :; do
  attempt=$((attempt + 1))
  keys="$(kubectl get secret backstage-secrets -n "${ns}" \
    -o jsonpath='{.data}' 2>/dev/null | jq 'length' 2>/dev/null || true)"
  keys="${keys:-0}"
  if [ "${keys}" = "4" ]; then
    echo "    backstage-secrets has ${keys}/4 keys"
    break
  fi
  if [ "${attempt}" -ge 90 ]; then
    echo "timeout: backstage-secrets never reached 4 keys" >&2
    exit 1
  fi
  sleep 5
done

echo "==> installing openchoreo-control-plane ${OPENCHOREO_VERSION}"
helm upgrade --install openchoreo-control-plane \
  oci://ghcr.io/openchoreo/helm-charts/openchoreo-control-plane \
  --version "${OPENCHOREO_VERSION}" \
  --namespace "${ns}" \
  --values "${OCP_VALUES_FILE}" \
  --wait --timeout 600s

echo "==> waiting for the cluster-gateway CA the chart provisions via cert-manager"
kubectl wait --for=condition=Ready certificate/cluster-gateway-ca -n "${ns}" --timeout=300s || true

echo "==> waiting for control-plane deployments to become available"
kubectl wait --for=condition=available deployment --all -n "${ns}" --timeout=600s || true

echo "OpenChoreo control plane ${OPENCHOREO_VERSION} is installed in namespace ${ns}."
