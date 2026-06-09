# LTG408: The developer experience with AKS Desktop and VS Code

Getting an app from local dev or on‑prem to AKS can be hard to make secure, repeatable, and easy to run. This session shows how AKS Desktop and VS Code speed the developer‑to‑AKS journey, from local Kubernetes workflows and containerization to CI/CD and safe deployments, using built‑in Kubernetes best practices for reliable operations.

```bash
terraform init
terraform apply
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
kubectl port-forward svc/argocd-server -n argocd 9000:443 &
argocd login localhost:8080 --sso --insecure
argocd account get-user-info
```

Reference:

- [Securing Argo CD with Microsoft Entra ID: A Step-by-Step Guide](https://blog.aks.azure.com/2026/04/22/argocd-extension-with-microsoft-entra)