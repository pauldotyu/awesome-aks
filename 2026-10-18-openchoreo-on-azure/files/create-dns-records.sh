#!/usr/bin/env bash
#
# After the control plane is running, create (or update) the Azure DNS A records
# that point console.<domain> and api.<domain> at the control-plane kgateway
# LoadBalancer public IP. This runs as a Terraform-managed step so the records
# stay in sync with the cluster's IP on re-apply.
#
# The zone may live in a different subscription than the cluster, so the
# subscription is passed explicitly.
#
set -euo pipefail

: "${KUBECONFIG_FILE:?KUBECONFIG_FILE must be set}"
: "${OCP_NAMESPACE:?OCP_NAMESPACE must be set}"
: "${DNS_ZONE:?DNS_ZONE must be set}"
: "${RESOURCE_GROUP:?RESOURCE_GROUP must be set}"
: "${DNS_SUBSCRIPTION_ID:?DNS_SUBSCRIPTION_ID must be set}"

export KUBECONFIG="${KUBECONFIG_FILE}"
ns="${OCP_NAMESPACE}"
sub="${DNS_SUBSCRIPTION_ID}"

echo "==> resolving the control-plane gateway LoadBalancer IP"
ip=""
attempt=0
while :; do
  attempt=$((attempt + 1))
  ip="$(kubectl get svc gateway-default -n "${ns}" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [ -n "${ip}" ] && break
  if [ "${attempt}" -ge 90 ]; then
    echo "timeout: gateway-default LoadBalancer IP never became available" >&2
    exit 1
  fi
  sleep 10
done
echo "    gateway-default IP = ${ip}"

for sub_name in console api; do
  existing="$(az network dns record-set a show \
    --subscription "${sub}" \
    --zone-name "${DNS_ZONE}" --resource-group "${RESOURCE_GROUP}" --name "${sub_name}" \
    --query id -o tsv 2>/dev/null || true)"

  if [ -n "${existing}" ] && az resource show --ids "${existing}" \
    --query "properties.rrset[0].ipv4-address" -o tsv 2>/dev/null | grep -qx "${ip}"; then
    echo "    ${sub_name}.${DNS_ZONE} already points at ${ip}"
  elif [ -n "${existing}" ]; then
    echo "    updating ${sub_name}.${DNS_ZONE} -> ${ip}"
    az resource update --ids "${existing}" --set "properties.rrset=[{\"ipv4-address\":\"${ip}\"}]"
  else
    echo "    creating ${sub_name}.${DNS_ZONE} -> ${ip}"
    az network dns record-set a add-record \
      --subscription "${sub}" \
      --zone-name "${DNS_ZONE}" --resource-group "${RESOURCE_GROUP}" \
      --record-set-name "${sub_name}" --ipv4-address "${ip}"
  fi
done

echo "DNS A records for console.${DNS_ZONE} and api.${DNS_ZONE} point at ${ip}."
