# Microsoft Build 2023 Pre-Day Containers Workshop

This Terraform code is what I used to provision a lab environment for all attendees of the Microsoft Build 2023 Pre-Day Containers Workshop. 

The goal of the workshop was to focus more on how to package applications for hosting on Azure Kubernetes Service (AKS) and less on how to provision the infrastructure. Therefore, I needed to pre-provision the infrastructure. This code created user accounts, AKS clusters, and other Azure resources for each attendee and usernames and passwords were distributed to attendees at the start of the workshop. 

Each attendee was assigned the Owner role to their own resource group which contained all of their resources. To save cost and meet quota limiations, I also created a shared resource group for things like Azure Log Analytics workspaces, Azure Managed Grafana, and Azure Load Testing.

Here's how to use this code to provision your own lab environment.

## Permissions

Make sure you have elevated privileges in your Azure AD tenant to create user accounts, app registrations, and service principals.

## Register providers and features

Make sure you have the following providers registered in your Azure subscription:

```bash
az provider register --namespace Microsoft.Quota
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ApiManagement
az provider register --namespace Microsoft.Monitor
az provider register --namespace Microsoft.AlertsManagement
az provider register --namespace Microsoft.Dashboard
az provider register --namespace Microsoft.App
```

## Ensure you have enough quota

Go to the Subscription blade, navigate to "Usage + Quotas", and make sure you have enough quota for the following resources:

- Regional vCPUs
- Standard Dv4 Family vCPUs

## Register features

Make sure you have the following features enabled in your Azure subscription:

```bash
az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "EnableWorkloadIdentityPreview"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AKS-GitOps"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AzureServiceMeshPreview"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AKS-KedaPreview"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AKS-PrometheusAddonPreview"
```

## Enable dynamic extension install for Azure CLI

```bash
az config set extension.use_dynamic_install=yes_without_prompt
```

## Provision infrastructure

Create a `terraform.tfvars` file with the following content:

```text
deployment_locations = [
  {
    offset   = 0 # adjust this to the number of users that have already been created in the previous set
    count    = 1 # adjust this to the number of users you want to create
    location = "eastus"
    vm_sku   = "Standard_D4s_v4"
  }
]
```

## Watch out for regional limitations for services

[Unsupported regions (user-assigned managed identities)](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation-considerations)

## Running the infrastructure provisioning

```bash
terraform apply -var-file=terraform.tfvars -parallelism=256
```