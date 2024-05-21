# AKS Automatic with Azure CLI

This is a guide to create an AKS Automatic cluster with Azure CLI.

Before you begin, you need to have the Azure CLI installed. If you don't have it installed, you can follow the instructions [here](https://docs.microsoft.com/cli/azure/install-azure-cli).

Ensure you are logged in to your Azure account by running the following command:

```bash
az login
```

Ensure you have the following extensions installed:

```bash
az extension add --name aks-preview
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

Once you have the extensions and features enabled, you can create an AKS Automatic cluster by running the commands in the sample [script](./deploy.sh).