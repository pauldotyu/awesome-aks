# AKS Store Demo Deployment using Helm

This Terraform configuration will deploy the following:

- Azure Kubernetes Service (AKS) cluster with the following configuration
  - AzureLinux (OS)
  - KEDA
  - Network Observability
  - Workflow Identity + OIDC Issuer URL
- Azure Managed Prometheus
- Azure Managed Grafana
- Azure OpenAI Service
- Azure Managed Identity with Federated Credential and role assignment for passwordless authentication to AOAI from AKS
- Helm release to deploy [aks-store-demo](https://github.com/azure-samples/aks-store-demo)
  - NOTE: This deployment does not include ingress. You will need to use port-forwarding to access the application.

## Pre-requisites

You will need the following tools installed on your machine:

- [Azure Subscription](https://azure.microsoft.com/get-started/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm CLI](https://helm.sh/docs/intro/install/)
- [Terraform](https://www.terraform.io/downloads.html)

## Getting started

Login to the Azure CLI using `az login` and then run the following command to register the extensions:

```bash
az login
```

Before running the `terraform apply` command, be sure you have Azure CLI installed and logged in using `az login`. It is also important to ensure you have the `AKS-KedaPreview` and `NetworkObservabilityPreview` features enabled in your subscription.

The following command will enable the features in your subscription:

```bash
az feature register --namespace "Microsoft.ContainerService" --name "NetworkObservabilityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-KedaPreview"
```

You should also have the following Azure CLI extensions installed:

```bash
az extension add --name aks-preview
az extension add --name amg
```

## Deploy the infrastructure using Terraform

The following commands will deploy the infrastructure using Terraform:

```bash
terraform init
terraform apply
```

Connect to the AKS cluster

```bash
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
```

## Validating the application

Run the following command to port forward to the store-front application:

```bash
kubectl port-forward svc/store-front 8080:80
```

In another terminal, run the following command to port forward to the store-admin application:

```bash
kubectl port-forward svc/store-admin 8081:80
```

## Cleanup

Run the following command to destroy the infrastructure:

```bash
terraform destroy
```

## Feedback

Please provide any feedback on this sample as a GitHub issue.
