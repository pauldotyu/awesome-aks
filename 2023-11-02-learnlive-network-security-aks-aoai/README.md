# Microsoft Reactor Learn Live: Network Security and Access for Intelligent Applications on Azure Kubernetes Service

This example is the end-to-end deployment of all resources that were presented as part of the [Microsoft Reactor Learn Live](https://aka.ms/cloudnative/learnlive/IntelligentAppsWithAKS) event on November 2, 2023.

To see how to deploy each component manually using Azure CLI, see this workshop: [Securing Network Access to Azure OpenAI from AKS](https://aka.ms/secure-aoai-aks-lab-part-2)

## Pre-requisites

You will need the following tools installed on your machine:

- [Azure Subscription](https://azure.microsoft.com/get-started/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Terraform](https://www.terraform.io/downloads.html)
- OPTIONAL: [Helm](https://helm.sh/)

## Getting started

Login to the Azure CLI using `az login` and then run the following command to register the extensions:

```bash
az login
```

Run the following command to register the required providers and extensions.

```bash
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.NetworkFunction
az provider register --namespace Microsoft.ServiceNetworking
```

You should also have the following Azure CLI extensions installed:

```bash
az extension add --name aks-preview
az extension add --name alb
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

## Verify the deployment

Run the following command to verify the deployment:

```bash
kubectl get po -n dev
```

## Test the applications

Run the following command to verify the deployment:

```bash
terraform output
```

You will see `store_front_fqdn` and `store_admin_fqdn`. Copy these values and paste them into your browser to verify that the application is running.

## Cleanup

Run the following command to destroy the infrastructure:

```bash
terraform destroy
```

## Feedback

Please provide any feedback on this sample as a GitHub issue.
