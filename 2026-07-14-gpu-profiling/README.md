# GPU Profiling Quickstart with Terraform

Work in progress...

My Terraform implementation of the [GPU Profiling for AKS](https://learn.microsoft.com/en-us/azure/aks/gpu-profiling)

Run the Terraform apply command and enter `yes` when prompted to deploy the Azure resources.

```bash
terraform apply
```

Terraform outputs to environment variables for use in the next steps.

```bash
read -r RG_NAME AKS_NAME GRAFANA_NAME PROMETHEUS_NAME PROMETHEUS_ENDPOINT PYROSCOPE_URL <<< "$(terraform output -json | jq -r '[.rg_name.value,.aks_name.value,.grafana_name.value,.prometheus_name.value,.prometheus_endpoint.value,.pyroscope_url.value] | @tsv')"
```

```bash
az grafana data-source create -n "$GRAFANA_NAME" -g "$RG_NAME" --definition "{
  \"name\": \"local-pyroscope\",
  \"uid\": \"local-pyroscope\",
  \"type\": \"grafana-pyroscope-datasource\",
  \"access\": \"proxy\",
  \"url\": \"${PYROSCOPE_URL}\",
  \"jsonData\": { \"keepCookies\": [\"pyroscope_git_session\"] }
}" --debug

az grafana data-source show -n "$GRAFANA_NAME" --data-source local-pyroscope
```

```bash
az grafana dashboard create \
  -n "$GRAFANA_NAME" \
  -g "$RG_NAME" \
  --definition "$(curl -sSL https://gist.githubusercontent.com/mqasimsarfraz/fca8e2394beb7454f467cf82785e2ee3/raw/2eb00a3853362bc863c292283041e8e283fe46ed/AdvancedGPUObservability.json)"
```

```bash
GRAFANA_URL=$(az grafana show -n "$GRAFANA_NAME" -g "$RG_NAME" --query properties.endpoint -o tsv)
echo "${GRAFANA_URL}/d/AdvancedGPUObservability"
```

Log into the AKS cluster.

```bash
az aks get-credentials -g "$RG_NAME" -n "$AKS_NAME"
```

```bash
kubectl apply -f - <<EOF
apiVersion: kaito.sh/v1beta1
kind: Workspace
metadata:
  name: workspace-granite-4-1-3b
inference:
  preset:
    accessMode: public
    name: ibm-granite/granite-4.1-3b
resource:
  count: 1
  instanceType: Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      app: workspace-granite-4-1-3b
EOF
```

T4 compute capability 7.5; therefore, it is unable to use FlashAttention 2. FA2 is only supported on devices with compute capability >=8 so will need to fall back to TRITON_ATTN

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: workspace-granite-4-1-3b-config
data:
  inference_config.yaml: |
    vllm:
      attention-backend: TRITON_ATTN 
---
apiVersion: kaito.sh/v1beta1
kind: Workspace
metadata:
  name: workspace-granite-4-1-3b
inference:
  config: workspace-granite-4-1-3b-config
  preset:
    accessMode: public
    name: ibm-granite/granite-4.1-3b
resource:
  count: 1
  instanceType: Standard_NC4as_T4_v3
  labelSelector:
    matchLabels:
      app: workspace-granite-4-1-3b
EOF
```
