# Anyscale on AKS

Terraform implementation of Anyscale on AKS. This deploys a full Anyscale-on-AKS stack using the AzAPI provider to create the `Anyscale.Platform` resources.

Terraform creates:

- Resource group
- AKS cluster (Standard tier) with Gateway API and Istio app routing enabled
- Anyscale operator installed as an AKS extension
- User-assigned managed identity with federated credential for the Anyscale operator
- Azure Container Registry (Standard SKU)
- Storage account with HNS enabled and a private blob container
- Azure Monitor workspace, Log Analytics workspace, and Application Insights with OTLP endpoints
- Prometheus data collection rules, endpoints, and alert rule groups
- Anyscale Cloud and Cloud Resource via AzAPI (`Anyscale.Platform/clouds`)
- Role assignments: Storage Blob Data Owner, AcrPush, Container Registry Tasks Contributor, AcrPull (kubelet), AKS RBAC Cluster Admin, Anyscale Platform Contributor

A `sample-workload/` directory contains a Ray job manifest and Python script you can use to verify the deployment.

## Prerequisites

- Azure CLI authenticated to a subscription with the following Azure resource providers registered:
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

> [!TIP]
> The AzureRM Terraform provider will automatically register required resource providers during deployment. If your account lacks permission to register providers, register them manually with `az provider register --namespace <provider-name>` before running `terraform apply`.

- Terraform installed
- Anyscale CLI installed

> [!CAUTION]
Anyscale on Azure is currently in preview and available in select regions. See [supported regions](https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions) for the latest list. Check the `location` variable in [variables.tf](./variables.tf) for the regions validated by this config.

## Deploy

Login to your Azure account and set the subscription you want to use.

```bash
az login
az account set -s <subscription-id>
```

Export the subscription ID for Terraform to use.

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

Initialize Terraform and deploy.

```bash
terraform init
terraform apply
```

Review the variables in [variables.tf](./variables.tf) before deploying. Key options:

- `location` - Azure region (default: `westus3`)
- `system_node_pool_vm_count_min` - Minimum number of system pool nodes (default: `3`)
- `system_node_pool_vm_count_max` - Maximum number of system pool nodes (default: `9`)

Get the outputs

```bash
read -r \
  RG_NAME \
  AKS_NAME \
  ANYSCALE_CLIENT_ID \
  ANYSCALE_CLOUD_NAME \
  ANYSCALE_CLOUD_ID \
  ANYSCALE_CLOUD_SSO_URL \
  ANYSCALE_CLOUD_RESOURCE_ID <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .anyscale_iam_client_id.value,
      .anyscale_cloud_name.value,
      .anyscale_cloud_id.value,
      .anyscale_cloud_sso_url.value,
      .anyscale_cloud_resource_id.value] | @tsv')"
```

Log into the AKS cluster.

```bash
az aks get-credentials -g $RG_NAME -n $AKS_NAME
```

Deploy the gateway

```bash
kubectl apply -f anyscale-gateway.yaml
```

The `anyscale-gateway.yaml` manifest is generated from [anyscale-gateway.tmpl](./anyscale-gateway.tmpl) by Terraform.

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

Submit the sample Ray job to confirm end-to-end. The `--cloud` flag takes the full Azure resource ID of the Anyscale cloud.

```bash
cd sample-workload
anyscale job submit -f job.yaml --cloud $ANYSCALE_CLOUD_RESOURCE_ID --wait
```

## Cleanup

```bash
terraform destroy
```
