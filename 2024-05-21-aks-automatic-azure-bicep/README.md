# AKS Automatic with Azure Bicep

This is a guide to create an AKS Automatic cluster with Azure Bicep.

Before you begin, you need to have the Azure CLI installed. If you don't have it installed, you can follow the instructions [here](https://docs.microsoft.com/cli/azure/install-azure-cli).

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
az group create -n myResourceGroup -l eastus
az deployment group create --resource-group myResourceGroup --template-file ./main.bicep --parameters name=demo$RANDOM userObjectId=$(az ad signed-in-user show --query id -o tsv)
```