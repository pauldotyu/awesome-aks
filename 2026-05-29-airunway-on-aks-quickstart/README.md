# AI Runway on AKS Quickstart

This Terraform sample stands up an opinionated AKS environment for running AI inference workloads. It is the infrastructure side of the [ai-runway-takeoff](https://github.com/pauldotyu/ai-runway-takeoff) GitOps repo: once Terraform finishes, Argo CD takes over and syncs the workloads from there.

Terraform creates:

- Resource group, VNet, and three subnets (`default`, `inference`, `lustre`)
- AKS cluster (Kubernetes 1.35) with a system node pool and an A100 GPU node pool (`Standard_NC48ads_A100_v4`) running with `gpu_driver = "None"` so the NVIDIA GPU Operator manages drivers
- Azure Managed Lustre File System (`AMLFS-Durable-Premium-500`, 4 TB)
- Helm installs for the NVIDIA GPU Operator, Istio (with the Gateway API Inference Extension enabled), and Argo CD
- A rendered `azurelustre-static.yaml` StorageClass wired to the Lustre MGS IP

> [!important]
> The GPU node pool uses `Standard_NC48ads_A100_v4`. Make sure your subscription has quota for this SKU in the region you pick.

## Prerequisites

- Azure CLI authenticated to a subscription
- Terraform installed
- kubectl installed
- Argo CD CLI installed

The `location` variable defaults to `brazilsouth`. Override it with any region that supports Azure Managed Lustre (see `variables.tf` for the full list).

## Provision Azure resources

Initialize Terraform and provision the Azure resources:

```bash
terraform init
terraform apply -auto-approve
```

Read the Terraform outputs for use in the next steps:

```bash
read -r RG_NAME AKS_NAME <<< "$(terraform output -json | jq -r '[.rg_name.value,.aks_name.value] | @tsv')"
```

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME
```

## Apply the Lustre StorageClass

Terraform renders `azurelustre-static.yaml` from `azurelustre-static.tmpl` with the live Lustre MGS IP. Apply it once the cluster is reachable:

```bash
kubectl apply -f azurelustre-static.yaml
```

## Log in to Argo CD

Port-forward to the Argo CD API server (this will occupy the terminal):

```bash
kubectl port-forward svc/argo-cd-argocd-server -n argocd 9000:80
```

Open a **new terminal tab**, retrieve the initial admin password, and log in:

```bash
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:9000 --username admin --password "$ARGOCD_PWD" --insecure
```

The UI is also available at <http://localhost:9000> using the same credentials.

## Bootstrap the workloads

Apply the app-of-apps to point Argo CD at the [ai-runway-takeoff](https://github.com/pauldotyu/ai-runway-takeoff) repo. Argo CD will then sync everything under `argocd/apps` in that repo.

```bash
kubectl apply -f app-of-apps.yaml
```

To verify the workloads are running, you can check the Argo CD UI or use the CLI:

```bash
argocd app list
```

## Learn more

From here, you can run through the [Build26-LAB510-take-llms-from-prototype-to-production-on-aks](https://github.com/microsoft/Build26-LAB510-take-llms-from-prototype-to-production-on-aks/blob/main/docs/1-core-concepts.md) lab guide to learn about the core concepts of AI Runway.

## Cleanup

When you are done, delete the Azure resources (this also removes the AKS cluster and all Kubernetes resources):

```bash
terraform destroy -refresh=false -auto-approve
```

## References

- [Azure Lustre CSI driver examples](https://github.com/kubernetes-sigs/azurelustre-csi-driver/tree/main/docs/examples)
- [ai-runway-takeoff GitOps repo](https://github.com/pauldotyu/ai-runway-takeoff)