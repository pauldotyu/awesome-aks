# AKS Automatic with Terraform and the AzAPI Provider

This is a guide to create an AKS Automatic cluster with Terraform including full cluster onboarding for monitoring.

Before you begin, you need to have the Azure CLI installed. If you don't have it installed, you can follow the [How to install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) guide.

You also need to have Terraform installed. If you don't have it installed, you can follow the [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) guide.

Log in to your Azure account by running the following command:

```bash
az login
```

Set an environment variable for your subscription ID by running the command:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

Ensure you are deploying to a region that supports API Server VNet Integration. See the [Use API Server VNet integration docs](https://learn.microsoft.com/azure/aks/api-server-vnet-integration#limited-availability) to get the list of supported regions.

This example deploys an Azure DNS Zone to demonstrate AKS App Routing with a custom domain. If you don't have a real domain, you can use example.com and update your hosts file to point to the app routing IP address.

Also, be sure to have an email address you can use to receive alert emails.

```bash
terraform init
terraform apply -var dns_zone_name=<put-your-domain-name-here> -var alert_email=<put-your-email-here>
```

Get the kubeconfig for the cluster by running the command:

```bash
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
```

You can then verify connectivity to the cluster by running the command:

```bash
kubectl cluster-info
```
