# Progressive Delivery on AKS with Argo Rollouts, Istio, and Gateway API

TODO: This is a work in progress and will be updated with more details.

## Pre-requisites

You will need the following tools installed on your machine:

- [Azure Subscription](https://azure.microsoft.com/get-started/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Terraform](https://www.terraform.io/downloads.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd)
- [Argo Rollouts Kubectl Plugin](https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation)

## Getting started

Login to the Azure CLI using `az login` and then run the following command to register the extensions:

```bash
az login
```

Before running the `terraform apply` command, be sure you have Azure CLI installed and logged in using `az login`. It is also important to ensure you have the required preview features enabled in your subscription.

The following command will enable the features in your subscription:

```bash
az feature register --namespace "Microsoft.ContainerService" --name "AzureServiceMeshPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AdvancedNetworkingPreview"
az feature register --namespace "Microsoft.ContainerService" --name "CiliumDataplanePreview"
```

You should also have the following Azure CLI extensions installed:

```bash
az extension add --name aks-preview
az extension add --name amg
```

> [!NOTE]
> Make sure you are in the same directory as this README before running the commands below.

## Deploy the infrastructure with Terraform

The following commands will deploy the infrastructure with Terraform:

```bash
terraform init
terraform apply
```

After the deployment is complete, export output variables which will be used in the next steps:

```bash
export RG_NAME=$(terraform output -raw rg_name)
export AKS_NAME=$(terraform output -raw aks_name)
export OAI_GPT_ENDPOINT=$(terraform output -raw oai_gpt_endpoint)
export OAI_GPT_DEPLOYMENT_NAME=$(terraform output -raw oai_gpt_deployment_name)
export OAI_DALLE_ENDPOINT=$(terraform output -raw oai_dalle_endpoint)
export OAI_DALLE_DEPLOYMENT_NAME=$(terraform output -raw oai_dalle_deployment_name)
export OAI_DALLE_API_VERSION=$(terraform output -raw oai_dalle_api_version)
export OAI_IDENTITY_CLIENT_ID=$(terraform output -raw oai_identity_client_id)
export AMG_NAME=$(terraform output -raw amg_name)
```

Connect to the AKS cluster

```bash
az aks get-credentials --name $AKS_NAME --resource-group $RG_NAME
```

Configure Azure Managed Prometheus to scrape metrics from any Pod across all Namespaces that have Prometheus annotations. This will enable the Istio metrics scraping.

```bash
kubectl create configmap -n kube-system ama-metrics-prometheus-config --from-file prometheus-config
```

Import the Istio dashboard into the Azure Managed Grafana instance.

```bash
az grafana dashboard import \
  --name $AMG_NAME \
  --resource-group $RG_NAME \
  --folder 'Azure Managed Prometheus' \
  --definition 7630
```

> More dashboards can be found [here](https://grafana.com/orgs/istio)

## AKS store demo app deployment with ArgoCD

Update the current context to the ArgoCD namespace:

```bash
kubectl config set-context --current --namespace=argocd
```

> [!NOTE]
> The ArgoCD custom resource defintions (CRDs) were installed as part of the Terraform deployment.

Connect to the ArgoCD server:

```bash
argocd login --core
```

Deploy the ArgoCD application:

```bash
kubectl create namespace pets
kubectl label namespace pets istio.io/rev=asm-1-21
argocd app create pets --sync-policy auto -f https://raw.githubusercontent.com/pauldotyu/aks-store-demo/ai-tour/sample-manifests/argocd/pets.yaml
```

Check the status of the application and wait for the **STATUS** to be **Synced** and **HEALTH** to be **Healthy**:

```bash
argocd app list
```

Optionally, you can use the ArgoCD Release Server UI to watch the application deployment.

Run the following command then click on the link below to open the ArgoCD UI:

```bash
argocd admin dashboard
```

Deploy the Gateway for the application:

> [!WARNING]
> The [Kubernetes Gateway API](https://github.com/kubernetes-sigs/gateway-api) project is still under active development and its CRDs are not installed by default in Kubernetes. You will need to install them manually. Keep an eye on the project's [releases](https://github.com/kubernetes-sigs/gateway-api/releases) page for the latest version of the CRDs.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```

Once the Gateway API CRDs are installed, you can deploy the Gateway and HTTPRoute resources:

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-external
  namespace: aks-istio-ingress
spec:
  gatewayClassName: istio
  addresses:
  - value: aks-istio-ingressgateway-external.aks-istio-ingress.svc.cluster.local
    type: Hostname
  listeners:
  - name: default
    hostname: "*.aks.rocks"
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: store-front
  namespace: pets
spec:
  parentRefs:
  - name: gateway-external
    namespace: aks-istio-ingress
  hostnames: ["store.aks.rocks"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: store-front
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: store-admin
  namespace: pets
spec:
  parentRefs:
  - name: gateway-external
    namespace: aks-istio-ingress
  hostnames: ["admin.aks.rocks"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: store-admin
      port: 80
EOF
```

## Validate AKS store demo application

Run the following command to get the public IP address of the application:

```bash
INGRESS_PUBLIC_IP=$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -IL "http://${INGRESS_PUBLIC_IP}" -H "Host: store.aks.rocks"
```

Open your hosts file and add the following entry:

```bash
<YOUR_INGRESS_PUBLIC_IP> store.aks.rocks
```

Now you can browse to the application using the URL: [http://store.aks.rocks](http://store.aks.rocks)

## Deploy ai-service using Argo Rollouts

Let's deploy the ai-service using Argo Rollouts:

> [!NOTE]
> The Argo Rollouts custom resource defintions (CRDs) were installed as part of the Terraform deployment.

To enable Argo Rollouts to use the Gateway API, you will need to install the TrafficRouter plugin. This can be done by creating a ConfigMap in the `argo-rollouts` namespace that points to the plugin binary. Latest versions of the plugin can be found [here](https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases).

Install the TrafficRouter plugin:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: argo-rollouts-config
  namespace: argo-rollouts
data:
  trafficRouterPlugins: |-
    - name: "argoproj-labs/gatewayAPI"
      location: "https://github.com/argoproj-labs/rollouts-plugin-trafficrouter-gatewayapi/releases/download/v0.3.0/gateway-api-plugin-linux-amd64"
EOF
```

Restart the Argo Rollouts controller to pick up the new plugin:

```bash
kubectl rollout restart deployment -n argo-rollouts argorollouts-release-argo-rollouts
```

Inspect the logs to ensure the plugin was loaded:

```bash
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts | grep gatewayAPI
```

Allow the Argo Rollouts controller to edit HTTPRoute resources:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gateway-controller-role
  namespace: argo-rollouts
rules:
  - apiGroups:
      - "*"
    resources:
      - "*"
    verbs:
      - "*"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gateway-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: gateway-controller-role
subjects:
  - namespace: argo-rollouts
    kind: ServiceAccount
    name: argorollouts-release-argo-rollouts
EOF
```

Create an HTTPRoute

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-internal
  namespace: aks-istio-ingress
spec:
  gatewayClassName: istio
  addresses:
  - value: aks-istio-ingressgateway-internal.aks-istio-ingress.svc.cluster.local
    type: Hostname
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ai-service
  namespace: pets
spec:
  parentRefs:
    - name: gateway-internal
      namespace: aks-istio-ingress
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: ai-service-stable
      kind: Service
      port: 5001
    - name: ai-service-canary
      kind: Service
      port: 5001
EOF
```

If you check the HTTPRoute, you will see that the weights are set to 100/0 for the stable and canary services. So all traffic is going to the stable service.

```bash
kubectl describe httproute ai-service -n pets
```

Create a two services:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ai-service-stable
  namespace: pets
spec:
  ports:
    - port: 5001
      targetPort: http
      name: http
  selector:
    app: ai-service
---
apiVersion: v1
kind: Service
metadata:
  name: ai-service-canary
  namespace: pets
spec:
  ports:
    - port: 5001
      targetPort: http
      name: http
  selector:
    app: ai-service
EOF
```

Create a ServiceAccount for the ai-service

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $OAI_IDENTITY_CLIENT_ID
  name: ai-service-account
  namespace: pets
EOF
```

Create a ConfigMap for the ai-service

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ai-service-configs
  namespace: pets
data:
  USE_AZURE_OPENAI: "True"  
  USE_AZURE_AD: "True"
  AZURE_OPENAI_ENDPOINT: $OAI_GPT_ENDPOINT
  AZURE_OPENAI_DEPLOYMENT_NAME: $OAI_GPT_DEPLOYMENT_NAME
  AZURE_OPENAI_DALLE_ENDPOINT: $OAI_DALLE_ENDPOINT
  AZURE_OPENAI_DALLE_DEPLOYMENT_NAME: $OAI_DALLE_DEPLOYMENT_NAME
  AZURE_OPENAI_API_VERSION: $OAI_DALLE_API_VERSION
EOF
```

Create the rollout for the ai-service. The actual manifest is [here](https://github.com/pauldotyu/aks-store-demo-manifests/blob/argo-rollout/ai-service/base/ai-service.yaml). Note the canary steps in the manifest. The first step sets the weight to 50% for the canary service. The second step pauses the rollout. The third step sets the weight to 100% for the canary service. The fourth step pauses the rollout and waits for a final promotion.

```bash
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ai-service
spec:
  destination:
    namespace: pets
    server: https://kubernetes.default.svc
  source:
    path: ai-service/overlays/dev
    repoURL: https://github.com/pauldotyu/aks-store-demo-manifests.git
    targetRevision: argo-rollout
  project: default
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
EOF
```

Watch the rollout and wait for **Status** to show **✔ Healthy**.

```bash
kubectl argo rollouts get rollout ai-service -n pets -w
```

When the rollout is healthy, hit **CTRL+C** to exit the watch then update the rollout to set the **ai-service** image to the **1.4.0** version.

```bash
kubectl argo rollouts set image ai-service -n pets ai-service=ghcr.io/pauldotyu/aks-store-demo/ai-service:1.4.0
```

Watch the rollout again and wait for **Status** to show **॥ Paused**.

```bash
kubectl argo rollouts get rollout ai-service -n pets -w
```

When the rollout is paused, hit **CTRL+C** to exit the watch then check the weights of the HTTPRoute. You should see that it has been updated to 50/50 traffic split between the stable and canary.

```bash
kubectl describe httproute ai-service -n pets
```

Promote the canary to next step to set the weight to 100%.

```bash
kubectl argo rollouts promote ai-service -n pets
```

Watch the rollout and wait for **Status** to show **॥ Paused**.

```bash
kubectl argo rollouts get rollout ai-service -n pets -w
```

When the rollout is paused, hit **CTRL+C** to exit the watch then check the weights of the HTTPRoute again. You should see that it has been updated to 0/100 traffic split with the canary service receiving all traffic.

```bash
kubectl describe httproute ai-service -n pets
```

All that is left is to promote the canary to the stable version.

```bash
kubectl argo rollouts promote ai-service -n pets
```

Watch the rollout one last time to see the stable version is now running version 1.4.0 and after a few minutes the rollout will scale down the **revision:1** ReplicaSet pods.

```bash
kubectl argo rollouts get rollout ai-service -n pets -w
```

When you see the **Status** show **✔ Healthy** and **revision:1** ReplicaSet status as **ScaledDown**, hit **CTRL+C** to exit the watch.

## Troubleshooting

Some common issues you may run into:

### Unable to browse to the site?

Take a look at the **PROGRAMMED** status of the Gateway:

```bash
kubectl get gtw -n aks-istio-ingress gateway-external
```

If the value for **PROGRAMMED** is not **True**, then take a look at the status conditions for the Gateway:

```bash
kubectl describe gtw -n aks-istio-ingress gateway-external
```

If you see something like the following, then check to see if the managed ingress gateway is properly deployed.

```text
Message:               Failed to assign to any requested addresses: hostname "aks-istio-ingressgateway-external.aks-istio-ingress.svc.cluster.local" not found
```

Run the command below. If you don't see the managed ingress gateway, then you may need to deploy it manually.

```bash
kubectl get svc -n aks-istio-ingress
```

Also check the logs for the Istio Ingress Gateway:

```bash
ISTIO_INGRESS_POD_1=$(kubectl get po -n aks-istio-ingress -l app=aks-istio-ingressgateway-external -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n aks-istio-ingress $ISTIO_INGRESS_POD_1

ISTIO_INGRESS_POD_2=$(kubectl get po -n aks-istio-ingress -l app=aks-istio-ingressgateway-external -o jsonpath='{.items[1].metadata.name}')
kubectl logs -n aks-istio-ingress $ISTIO_INGRESS_POD_2
```

### Unable to see your ConfigMap from Azure App Configuration?

Common things to check include:

1. Ensure RBAC is properly configured for the managed identity that the AKS extension created.
1. Ensure the federated credential is properly configured for the managed identity that the AKS extension created.
1. Ensure the Azure App Configuration provider for Kubernetes pod has Azure tenant environment variables set.
1. Ensure the ServiceAccount has the clientId annotation set.

Typically you will see an error in the logs of the Azure App Configuration provider for Kubernetes pod if there is an issue.

```bash
kubectl logs -n azappconfig-system -l app.kubernetes.io/name=appconfig-provider
```

## Cleanup

Run the following command to destroy the infrastructure:

```bash
terraform destroy
```

## Feedback

Please provide any feedback on this sample as a GitHub issue.

## Resources

- https://gateway-api.sigs.k8s.io/
- https://argoproj.github.io/argo-rollouts/
- https://rollouts-plugin-trafficrouter-gatewayapi.readthedocs.io/en/stable/
- https://rollouts-plugin-trafficrouter-gatewayapi.readthedocs.io/en/stable/quick-start/
