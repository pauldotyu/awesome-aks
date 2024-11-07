# LLMOps with AKS and KAITO

Work in progress...

Spin up the Azure resources then run the following commands:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
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

Watch the pods roll out.

```bash
kubectl get po -n pets -w
```

You can also watch the ArgoCD application status.

Get the initial password for the ArgoCD admin user.

```bash
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Port forward the ArgoCD server and login to the UI with username `admin` and the password from the previous step.

```bash
kubectl port-forward -n argocd svc/argocd-release-server 8080:443
```

Deploy the Argo Events manifests.

```bash
kustomize build ./manifests | kubectl apply -f -
```

Wait a few minutes and test the Prometheus ServiceMonitor configuration.

```bash
AMA_METRICS_POD_NAME="$(kubectl get po -n kube-system -lrsName=ama-metrics -o jsonpath='{.items[0].metadata.name}')"
kubectl port-forward $AMA_METRICS_POD_NAME -n kube-system 9090
```

If the first pod does not show the job configuration, try the second pod.

```bash
AMA_METRICS_POD_NAME="$(kubectl get po -n kube-system -lrsName=ama-metrics -o jsonpath='{.items[1].metadata.name}')"
kubectl port-forward $AMA_METRICS_POD_NAME -n kube-system 9090
```

Follow the logs of the sensor pod.

```bash
SENSOR_POD_NAME=$(kubectl get po -n pets -l owner-name=tuning-sensor -ojsonpath='{.items[0].metadata.name}')
kubectl logs -n pets $SENSOR_POD_NAME -f
```

Open a new terminal, port-forward the product-service.

```bash
kubectl port-forward -n pets svc/product-service 3002
```

Open a new terminal and test the product-service metrics endpoint.

```bash
curl http://localhost:3002/metrics
```

Gradually import the test data.

```bash
for i in {1..10}; do curl -X POST http://localhost:3002/import -H "Content-Type: application/json" --data-binary @testImport$i.json; echo "Processed testImport$i.json"; sleep 15; done
```

## Cleanup

```bash
terraform state rm kubernetes_namespace.example
terraform destroy --auto-approve
rm terraform.tfstate*
```
