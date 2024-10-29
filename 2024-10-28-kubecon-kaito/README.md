# LLMOps with AKS and KAITO

Work in progress...

Spin up the Azure resources then run the following commands:

Deploy the ArgoCD application which deploys the AKS Store Demo app.

```bash
kubectl apply -n argocd -f ~/repos/pauldotyu/aks-store-demo/sample-manifests/argocd/pets.yaml
```

Update the default namespace to use the `argocd` namespace.

```bash
kubectl config set-context --current --namespace=argocd
```

Force a sync of the ArgoCD application.

```bash
argocd app sync pets --force
```

Get the initial password for the ArgoCD admin user.

```bash
argocd admin initial-password
```

Port forward the ArgoCD server and login to the UI with username `admin` and the password from the previous step.

```bash
kubectl port-forward svc/argocd-release-server 8080:443
```

Set the default namespace back to `default`.

```bash
kubectl config set-context --current --namespace=default
```

After you're done testing, delete the ArgoCD application.

```bash
argocd app delete argocd/pets
```
