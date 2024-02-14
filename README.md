# awesome-aks

This is a collection of Azure Kubernetes Service (AKS) related Infrastructure-as-Code templates and scripts that I use for demos, testing, and blogs.

I'll create new IaC code as I go and will not be updating previous entries unless absolutely needed so things will get stale over time.

## Pre-requisites

- Bash shell
- Azure CLI
- Terraform
- kubectl
- Helm
- Azure subscription with permissions to create Azure and Azure AD resources, and assign roles


## Post-deployment

Deploy the [AKS Store Demo](https://github.com/Azure-Samples/aks-store-demo) sample app to the AKS cluster.

```bash
helm install aks-store-demo oci://ghcr.io/azure-samples/aks-store-demo/charts/aks-store-demo-chart \
  --version 1.0.0 \
  --namespace dev \
  --create-namespace
```
