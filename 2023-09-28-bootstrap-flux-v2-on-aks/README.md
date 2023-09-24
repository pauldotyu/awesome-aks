# Bootstrap GitOps with the Flux v2 AKS Extension using Terraform

This Terraform sample builds upon the learnings from my blog posts on [Automating Image Updates on AKS](https://aka.ms/cloudnative/ImageAutomationWithFluxCD) and [Progressive Delivery on AKS](https://aka.ms/cloudNative/ProgressiveDeliveryWithFlagger). It demonstrates how to use the Flux K8s extensions to deploy a sample application to an AKS cluster complete with Flux's image update automation and Flagger's progressive delivery capabilities.

## Pre-requisites

You will need the following tools installed on your machine:

- [Azure Subscription](https://azure.microsoft.com/get-started/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Flux CLI](https://fluxcd.io/flux/installation/)
- [Terraform](https://www.terraform.io/downloads.html)

## Getting started

Login to the Azure CLI using `az login` and then run the following command to register the extensions:

```bash
az login
```

Before running the `terraform apply` command, be sure you have Azure CLI installed and logged in using `az login`. It is also important to ensure you have the `AzureServiceMeshPreview` and `NetworkObservabilityPreview` features enabled in your subscription.

The following command will enable the features in your subscription:

```bash
az feature register --namespace "Microsoft.ContainerService" --name "AzureServiceMeshPreview"
az feature register --namespace "Microsoft.ContainerService" --name "NetworkObservabilityPreview"
```

You should also have the following Azure CLI extensions installed:

```bash
az extension add --name aks-preview
az extension add --name amg
```

Login into GitHub CLI using `gh auth login` and then run the following command:

```bash
# login with proper scopes
gh auth login -s repo,workflow
```

## Deploy the infrastructure using Terraform

The following commands will deploy the infrastructure using Terraform:

```bash
terraform init
terraform apply -var gh_user=$(gh api user --jq .login) -var gh_token=$(gh auth token)
```

Connect to the AKS cluster

```bash
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
```

## Check the Flux and Flagger installations

View all Flux controllers and CRDs that are installed.

```bash
flux check
```

View Flux sources

```bash
flux get sources all
```

View image update automation resources

```bash
flux get image all
```

View Kustomization resources

```bash
flux get kustomizations
```

### Troubleshooting

If you are seeing some `READY` status as `False` you can check the logs of the respective controller to see what is going on.

```bash
kubectl logs -n flux-system -l app=kustomize-controller
```

You could also run the `flux logs` and `flux events` commands to get more information.

Azure Managed Grafana and Azure Managed Prometheus is also installed as part of the deployment. You can follow instructions [here](https://learn.microsoft.com/azure/azure-arc/kubernetes/monitor-gitops-flux-2) to monitor the GitOps deployment via Grafana dashboards.

## Validating the application

Run the following command to get the public IP address of the application:

```bash
echo "http://$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

## Cleanup

Run the following command to destroy the infrastructure:

```bash
terraform destroy -var gh_user=$(gh api user --jq .login) -var gh_token=$(gh auth token)
```

## Feedback

Please provide any feedback on this sample as a GitHub issue.
