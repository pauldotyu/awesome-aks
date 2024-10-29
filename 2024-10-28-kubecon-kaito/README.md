# LLMOps with AKS and KAITO

Work in progress...

Spin up the Azure resources then run the following commands:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform apply
```

Connect to the AKS cluster.

```bash
az aks get-credentials -g $(terraform output -raw rg_name) -n $(terraform output -raw aks_name)
```

Deploy the ArgoCD application which deploys the AKS Store Demo app.

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/pauldotyu/aks-store-demo/refs/heads/bigbertha/sample-manifests/argocd/pets.yaml
```

Get the initial password for the ArgoCD admin user.

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Port forward the ArgoCD server and login to the UI with username `admin` and the password from the previous step.

```bash
kubectl port-forward -n argocd svc/argocd-release-server 8080:443
```
