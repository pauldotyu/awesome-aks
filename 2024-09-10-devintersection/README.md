# DEVintersection AKS Automatic Demo Setup

This is a demo setup script for a session I delivered at DEVintersection titled [AKS Automatic: The Easiest Managed Kubernetes Experience](https://devintersection.com/#!/session/AKS%20Automatic:%20The%20Easiest%20Managed%20Kubernetes%20Experience/7056).

The demo involves creating an AKS Automatic cluster using the Azure Portal, but like any good cooking show, this will be the pre-baked version of the demo 😉

Before you begin, you need to have the Azure CLI installed. If you don't have it installed, you can follow the instructions [here](https://docs.microsoft.com/cli/azure/install-azure-cli). 

You also need to have Terraform installed. If you don't have it installed, you can follow the instructions [here](https://learn.hashicorp.com/tutorials/terraform/install-cli).

Ensure you are logged in to your Azure account by running the following command:

```bash
az login
```

> [!NOTE]
> The 4.0.0+ version of azurerm provider now requires the subscription_id to be passed in the [azurerm provider block](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#subscription_id).

Run the following command to set the `ARM_SUBSCRIPTION_ID` environment variable:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
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