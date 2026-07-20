# Profiling GPU Memory for KubeRay Training Jobs on AKS with Anyscale

This project stands up an end-to-end environment for **profiling GPU workloads** on AKS. The goal: run a KubeRay training job on an [Anyscale](https://learn.microsoft.com/azure/anyscale-on-azure/overview) cloud backed by AKS, then use GPU profiling to see what the training code is actually doing to the GPU (memory utilization, kernel activity) so you can reason about efficiency and bottlenecks.

The profiling signal comes from [Inspektor Gadget](https://www.inspektor-gadget.io/)'s GPU observability, exported two ways:

- **Metrics** (GPU utilization, memory, temperature) scraped into **Azure Monitor managed Prometheus** and visualized in **Azure Managed Grafana**.
- **Continuous profiles** collected by **Grafana Pyroscope** running in-cluster, surfaced in Grafana as a Pyroscope data source so you can drill into GPU memory usage over time and correlate it with the training run.

## What Terraform creates

Core platform:

- **Resource group** (`rg-gpuprofiling<NN>`) holding everything.
- **AKS Automatic cluster** (deployed via AzAPI) with a system-assigned identity, Gateway API + Istio-based app routing enabled, Azure Monitor metrics (managed Prometheus) and Container Insights turned on, OpenTelemetry auto-instrumentation enabled, and deployment safeguards that exclude the `anyscale-operator`, `inspektor-gadget`, and `gadget` namespaces.
- **GPU node pool manifest** (`nvidia-nodepool.yaml`, generated from [nvidia-nodepool.tmpl](./nvidia-nodepool.tmpl)) that defines a Karpenter/NAP `AKSNodeClass` + `NodePool` for the fully managed GPU experience (AKS-managed NVIDIA drivers). VM size is controlled by the `nvidia_sku_name` variable (default `Standard_NC40ads_H100_v5`).

Observability and profiling:

- **Inspektor Gadget** installed as an AKS extension with `gpuObservability.enabled` and `azureMonitor.enabled`.
- **Grafana Pyroscope** installed via Helm into the `gadget` namespace, exposed on an internal load balancer fronted by an Azure Private Link Service (PLS) so Managed Grafana can reach it privately.
- **Azure Managed Grafana** (v12) integrated with the Azure Monitor workspace, with a managed private endpoint to the Pyroscope PLS.
- **Azure Monitor workspace** (managed Prometheus) with data collection endpoints/rules, recording rules, and alert rule groups, plus a **Log Analytics workspace** and **Application Insights** with OTLP logs/metrics/traces endpoints.

> [!IMPORTANT]
> Monitoring is wired up end to end for maximum signal during the demo, mirroring Azure's standard managed Prometheus + Container Insights onboarding. The Linux recording rule groups (`node`, `k8s`, `ux` in [prometheus.tf](./prometheus.tf)) are enabled and the Windows group (`uxw`) is disabled, matching the portal defaults. The main ingestion drivers here are Container Insights collecting container logs from **all** namespaces (`namespaceFilteringMode: Off`, ContainerLogV2) into Log Analytics, and managed Prometheus metric ingestion into the Azure Monitor workspace. The minimal ingestion profile (Azure's default cost control for scraped metrics) is on by default, but full-cluster log collection still adds up. For cost-sensitive or production environments, scope this down: enable namespace filtering, disable recording rule groups you do not need, and/or increase collection intervals.

Anyscale:

- **Azure Container Registry** (Standard) and a **storage account** (HNS enabled, private blob container) used as the Anyscale cloud's image registry and object storage.
- **User-assigned managed identity** with a federated credential for the Anyscale operator.
- **Anyscale Cloud** and **Cloud Resource** (`Anyscale.Platform/clouds`) via AzAPI, wired to the ACR and storage account.
- **Anyscale operator** installed as an AKS extension, configured to route ingress through the Istio gateway (`anyscale-gateway.yaml`, generated from [anyscale-gateway.tmpl](./anyscale-gateway.tmpl)).
- **Role assignments**: Storage Blob Data Owner, AcrPush, Container Registry Tasks Contributor (identity), AcrPull (kubelet), AKS RBAC Cluster Admin, Anyscale Platform Contributor, Grafana Admin, and Monitoring Data Reader (Grafana identity).

## Prerequisites

Install the following tools:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (to apply the GPU node pool manifest and inspect the cluster)
- [Anyscale CLI](https://docs.anyscale.com/reference/quickstart-cli) (to verify the Anyscale cloud)
- [jq](https://jqlang.github.io/jq/) (used to read Terraform outputs)

Then prepare your Azure subscription:

- Authenticate the Azure CLI to a subscription with the following resource providers registered:
  - Anyscale.Platform
  - Microsoft.Authorization
  - Microsoft.ContainerRegistry
  - Microsoft.ContainerService
  - Microsoft.Insights
  - Microsoft.ManagedIdentity
  - Microsoft.Monitor
  - Microsoft.Network
  - Microsoft.OperationalInsights
  - Microsoft.Resources
  - Microsoft.Storage

- Register the `ManagedGPUExperiencePreview` feature, required to create GPU node pools with AKS-managed NVIDIA drivers. Wait for registration to complete before deploying. See [Create a fully managed GPU node pool on Azure Kubernetes Service (AKS) (preview)](https://learn.microsoft.com/azure/aks/aks-managed-gpu-nodes?tabs=add-ubuntu-gpu-node-pool%2Cmig-single%2Cdriver-only) for details.

  ```bash
  az feature register --namespace Microsoft.ContainerService --name ManagedGPUExperiencePreview
  ```

> [!TIP]
> The AzureRM Terraform provider will automatically register required resource providers during deployment. If your account lacks permission to register providers, register them manually with `az provider register --namespace <provider-name>` before running `terraform apply`.

> [!CAUTION]
> Anyscale on Azure is currently in preview and available in select regions. See [supported regions](https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions) for the latest list. Check the `location` variable in [variables.tf](./variables.tf) for the regions validated by this config.

## Deploy

Login to your Azure account and set the subscription you want to use. The AzureRM provider (v4.35+) reads the subscription from your Azure CLI context, so no `ARM_SUBSCRIPTION_ID` export is needed for local CLI-authenticated runs.

```bash
az login
az account set -s <subscription-id>
```

Review the variables in [variables.tf](./variables.tf) before deploying. Key options:

- `location` - Azure region for most resources (default: `switzerlandnorth`). Choose a region running AKS release `v20260619` or later. Check the [AKS release tracker](https://releases.aks.azure.com/) for the version rolled out to each region.
- `anyscale_cloud_location` - Region for the Anyscale cloud resource, must be an Anyscale-supported region (default: `eastus`)
- `nvidia_sku_name` - GPU VM size for the NVIDIA node pool (default: `Standard_NC40ads_H100_v5`)

Initialize Terraform and deploy.

```bash
terraform init
terraform apply
```

Read the Terraform outputs into environment variables for the steps that follow.

```bash
read -r \
  RG_NAME \
  AKS_NAME \
  NRG \
  PLS_ID \
  ANYSCALE_CLIENT_ID \
  ANYSCALE_CLOUD_NAME \
  ANYSCALE_CLOUD_ID \
  ANYSCALE_CLOUD_SSO_URL \
  ANYSCALE_CLOUD_RESOURCE_ID \
  GRAFANA_NAME \
  GRAFANA_URL \
  PYROSCOPE_URL <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .node_resource_group.value,
      .pyroscope_pls_id.value,
      .anyscale_iam_client_id.value,
      .anyscale_cloud_name.value,
      .anyscale_cloud_id.value,
      .anyscale_cloud_sso_url.value,
      .anyscale_cloud_resource_id.value,
      .grafana_name.value,
      .grafana_url.value,
      .pyroscope_url.value] | @tsv')"
```

Log into the AKS cluster.

```bash
az aks get-credentials -g $RG_NAME -n $AKS_NAME
```

Apply the Anyscale Gateway manifest so the Anyscale operator can route ingress through the Istio gateway.

```bash
kubectl apply -f anyscale-gateway.yaml
```

Apply the GPU node pool manifest so Node Autoprovisioning can create GPU nodes (with AKS-managed NVIDIA drivers) on demand when a GPU workload is scheduled.

```bash
kubectl apply -f nvidia-nodepool.yaml
```

For more on the managed GPU experience with Node Autoprovisioning, see [Create a fully managed GPU node pool on Azure Kubernetes Service (AKS) (preview)](https://learn.microsoft.com/azure/aks/aks-managed-gpu-nodes?tabs=nap-managed-node%2Cmig-single%2Cdriver-only).

## Verify

Check that the Anyscale operator and gateway-related pods are running.

```bash
kubectl get po -A
```

Install the [Anyscale CLI](https://docs.anyscale.com/reference/quickstart-cli) and log in.

```bash
export ANYSCALE_HOST=https://console.azure.anyscale.com
anyscale login
```

Verify the cloud is registered and healthy.

```bash
anyscale cloud list
anyscale cloud verify --id $ANYSCALE_CLOUD_ID
```

## Grafana to Pyroscope connectivity and PLS auto-approval

> [!NOTE]
> On a default deploy (unchanged region and Grafana instance), Terraform already handles this end to end, so no manual steps are required here. Read this section to understand the mechanism, or if you rebuild Grafana in a different region and need to update the auto-approval subscription ID.

The Pyroscope service is exposed over an internal load balancer fronted by an Azure Private Link Service (PLS), created by the AKS cloud controller manager via `service.beta.kubernetes.io/azure-pls-*` annotations. Azure Managed Grafana connects to it through a managed private endpoint (MPE).

### What the auto-approval annotation is

When a private endpoint connects to a PLS, the connection starts in a **Pending** state and normally has to be approved before traffic flows. The `service.beta.kubernetes.io/azure-pls-auto-approval` annotation tells the AKS cloud controller manager to automatically approve incoming connections whose private endpoint lives in one of the listed subscriptions, so no manual approval step is needed. Its value is a comma-separated list of subscription IDs (wildcards are not supported).

### Why it is needed here

The AKS node resource group (`MC_*`) is protected by [NRG lockdown](https://aka.ms/aks/nrg_lockdown), which adds an Azure **deny assignment** to that resource group. The PLS is created in the node resource group, so approving the pending connection means writing to `Microsoft.Network/privateLinkServices/privateEndpointConnections` there. Deny assignments are evaluated above all role assignments, so this write is blocked even for a subscription Owner:

```text
RESPONSE 403: DenyAssignmentAuthorizationFailed
... the access is denied because of the deny assignment ... nrg-lockdown
```

No RBAC role can work around a deny assignment, and you cannot add yourself to the AKS-managed exclusions. The cloud controller manager, however, *is* excluded from the deny assignment. So instead of approving the connection ourselves, we set `azure-pls-auto-approval` and let the cloud controller manager perform the approval for us. This keeps NRG lockdown enabled for the rest of the cluster.

The value must be the subscription where the private endpoint actually lives. Managed Grafana provisions the MPE's underlying private endpoint in a **Microsoft-owned platform subscription** (per Grafana instance/region), not your subscription. That value is hardcoded in [pyroscope.tf](./pyroscope.tf); if you rebuild Grafana in a different region, look it up again from the Pyroscope PLS as shown below.

### Look up the auto-approval subscription ID

`NRG` (node resource group) and `PLS_ID` (Pyroscope PLS resource ID) are exported by the outputs block above. Use `PLS_ID` to read the pending connection's private endpoint subscription:

```bash
az network private-link-service show --ids "$PLS_ID" \
  --query "privateEndpointConnections[].privateEndpoint.id" -o tsv \
  | awk -F'/' '{print $3}'
```

Put that subscription ID into the `azure-pls-auto-approval` annotation value in [pyroscope.tf](./pyroscope.tf).

To check whether the connection has been approved:

```bash
az network private-link-service show --ids "$PLS_ID" \
  --query "privateEndpointConnections[].{sub:privateEndpoint.id, status:privateLinkServiceConnectionState.status}" -o table
```

## Configure Grafana data sources and dashboard

The managed Prometheus data source is already provisioned automatically by Azure Managed Grafana through the Azure Monitor workspace integration (configured in [grafana.tf](./grafana.tf)), so you only need to add the Pyroscope data source.

Once the Pyroscope private endpoint connection is approved (see above), add the Pyroscope data source. Grafana reaches Pyroscope over the managed private endpoint, so `PYROSCOPE_URL` is the private IP on port 4040.

```bash
az grafana data-source create -n "$GRAFANA_NAME" -g "$RG_NAME" --definition "{
  \"name\": \"local-pyroscope\",
  \"uid\": \"local-pyroscope\",
  \"type\": \"grafana-pyroscope-datasource\",
  \"access\": \"proxy\",
  \"url\": \"${PYROSCOPE_URL}\",
  \"jsonData\": { \"keepCookies\": [\"pyroscope_git_session\"] }
}"

az grafana data-source show -n "$GRAFANA_NAME" --data-source local-pyroscope
```

Import the Inspektor Gadget Advanced GPU Observability dashboard.

```bash
az grafana dashboard create \
  -n "$GRAFANA_NAME" \
  -g "$RG_NAME" \
  --definition "$(curl -sSL https://raw.githubusercontent.com/pauldotyu/awesome-aks/refs/heads/main/2026-07-17-kubecon-gpuprofiling/AdvancedGPUObservability.json)"
```

Open the dashboard.

```bash
echo "${GRAFANA_URL}/d/AdvancedGPUObservability"
```

## Run and profile a KubeRay training job on Anyscale

With the cluster, GPU node pool, and Grafana wired up, the demo flow is:

1. **Create a workspace/training template in the Anyscale cloud.** From the [Anyscale console](https://console.azure.anyscale.com) (the cloud registered above), run through the [Fine-tuning Stable Diffusion XL with Ray Train](https://console.anyscale.com/template-preview/finetune-stable-diffusion) template that targets this cloud. Anyscale provisions a KubeRay cluster on AKS (Ray head and worker pods), and Node Autoprovisioning brings up a GPU node from the `nvidia` node pool to satisfy the GPU request.
2. **Run a training job (notebook).** Launch a KubeRay training notebook/job that exercises the GPU (for example a model fine-tuning or training loop). Ray places the GPU work on the provisioned GPU node.
3. **Profile GPU memory utilization.** While the job runs, watch the signals in Grafana:
   - The **Advanced GPU Observability** dashboard (managed Prometheus) shows GPU utilization, memory used/free, and temperature per GPU.
   - The **Pyroscope** data source shows continuous GPU memory profiles so you can drill into how the training code allocates and holds GPU memory over the run.

The point of the exercise is to correlate what the training code is doing with its effect on the GPU: spotting memory that is allocated but idle, oversized batches, or phases of the job that leave the GPU underutilized, so you can tune the workload.

> [!NOTE]
> This section is a work in progress. The specific KubeRay training template and notebook used in the demo will be added here.

## Cleanup

```bash
terraform destroy
```
