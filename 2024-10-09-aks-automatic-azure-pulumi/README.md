# AKS Automatic with Pulumi

This is a guide to create an AKS Automatic cluster with Pulumi.

Before you begin, you need to have the Azure CLI installed. If you don't have it installed, you can follow the instructions [here](https://docs.microsoft.com/cli/azure/install-azure-cli).

You also need to have Pulumi installed. If you don't have it installed, you can follow the instructions [here](Pulumi).

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

Once you have the extensions and features enabled, you can create an AKS Automatic cluster with Pulumi.

You have an option when running the `pulumi up` command. You can use Pulumi's managed service to store your state or you can use a local state file. If you want to use Pulumi's managed service, you can run the following command:

```bash
pulumi login
```

If you want to use a local state file, you can run the following command:

```bash
pulumi login file://~/.pulumi
```

> You will be asked to create a `PULUMI_CONFIG_PASSPHRASE` when using a local state file. This is used to encrypt the state file and can be any string you choose.

Pulumi stores deployment state within stacks. This helps you manage different deployments of your infrastructure. You can create a new stack using the following command:

```bash
pulumi stack init dev
```

Before running the `pulumi up` command, be sure to configure the location for the resources using the following command:

```bash
pulumi config set azure-native:location <YOUR_PREFERRED_AZURE_REGION>
```

> Just make sure the region you choose supports AKS, Azure Monitor, and Azure Grafana.

The following command will install the `azure-native` plugin:

```bash
pulumi up -s dev
```

After running the `pulumi up` command, you will be prompted to confirm the changes. If everything looks good, you can type `yes` and hit enter. Within a few minutes, you will have an AKS cluster deployed in your Azure subscription.

From here, feel free to explore the cluster and the resources that were created and deploy your favorite application to the cluster.

## Clean up

To clean up the resources, you can run the following commands:

```bash
pulumi destroy -s dev
pulumi stack rm dev
```
