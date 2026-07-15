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
az grafana data-source create -n "$GRAFANA_NAME" -g "$RG_NAME" --definition "{
  \"name\": \"$PROMETHEUS_NAME\",
  \"type\": \"prometheus\",
  \"access\": \"proxy\",
  \"url\": \"$PROMETHEUS_ENDPOINT\",
  \"jsonData\": {
    \"httpMethod\": \"POST\",
    \"azureCredentials\": { \"authType\": \"msi\" }
  }
}" --debug

az grafana data-source show -n "$GRAFANA_NAME" --data-source "$PROMETHEUS_NAME"
```

```bash
az grafana dashboard create \
  -n "$GRAFANA_NAME" \
  -g "$RG_NAME" \
  --definition "$(curl -sSL https://raw.githubusercontent.com/inspektor-gadget/grafana-dashboards/refs/heads/main/dashboards/gpu-observability/AdvancedGPUObservability.json)"
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
  name: workspace-gemma4-e4b
inference:
  preset:
    accessMode: public
    name: google/gemma-4-E4B-it
resource:
  count: 1
  instanceType: Standard_NC40ads_H100_v5 #Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      app: workspace-gemma4-e4b
EOF
```
