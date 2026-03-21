# AKS Desktop at KubeCon EU 2026

Work in progress...

```sh
read -r RG_NAME AKS_NAME MF_API_BASE_URL MF_API_KEY MI_CLIENT_ID <<< "$(
  terraform output -json | jq -r '[
    .rg_name.value,
    .aks_name.value,
    .mf_api_base_url.value,
    .mf_api_key.value,
    .mi_client_id.value
  ] | @tsv'
)"
```

  ] | @tsv'
)"
```

```sh
az aks get-credentials \
--resource-group $RG_NAME \
--name $AKS_NAME
```

```sh
kubectl create namespace aks-agent-system
```

```sh
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aks-agent
  namespace: aks-agent-system
  annotations:
    azure.workload.identity/client-id: $MI_CLIENT_ID
EOF
```

```sh
az aks agent-init \
--resource-group $RG_NAME \
--name $AKS_NAME
```