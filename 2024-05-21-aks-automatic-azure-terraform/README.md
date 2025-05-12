# AKS Automatic with Terraform

> [!IMPORTANT]
> This was written using AzApi provider 1.13.1. If you are using AzApi 2.0 or higher, you no longer need to [`jsonencode` the body](https://github.com/pauldotyu/awesome-aks/blob/e8c01ce577b8cc98213d215c2887e0815427692f/2024-05-21-aks-automatic-azure-terraform/kubernetes.tf#L8) of a resource deployment. See this [doc](https://registry.terraform.io/providers/Azure/azapi/latest/docs/guides/2.0-upgrade-guide#dynamic-properties-support) for more information.

This is a guide to create an AKS Automatic cluster with Terraform.

Before you begin, you need to have the Azure CLI installed. If you don't have it installed, you can follow the instructions [here](https://docs.microsoft.com/cli/azure/install-azure-cli). 

You also need to have Terraform installed. If you don't have it installed, you can follow the instructions [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).

Ensure you are logged in to your Azure account by running the following command:

```bash
az login
```

Ensure you have the following preview features enabled in your subscription:

```bash
az feature register --namespace Microsoft.ContainerService --name EnableAPIServerVnetIntegrationPreview
az feature register --namespace Microsoft.ContainerService --name NRGLockdownPreview
az feature register --namespace Microsoft.ContainerService --name SafeguardsPreview
az feature register --namespace Microsoft.ContainerService --name NodeAutoProvisioningPreview
az feature register --namespace Microsoft.ContainerService --name DisableSSHPreview
az feature register --namespace Microsoft.ContainerService --name AutomaticSKUPreview
az provider register --namespace Microsoft.ContainerService
```

Once you have the extensions and features enabled, you can create an AKS Automatic cluster by running the commands:

```bash
terraform init
terraform apply
```
