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
```

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
export AC_ID=$(terraform output -raw ac_id)
export AC_ENDPOINT=$(terraform output -raw ac_endpoint)
export OAI_IDENTITY_CLIENT_ID=$(terraform output -raw oai_identity_client_id)
```

Connect to the AKS cluster

```bash
az aks get-credentials --name $AKS_NAME --resource-group $RG_NAME
```

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
  name: gateway
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
  - name: gateway
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
  - name: gateway
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

## Sync ai-service configs with Azure AppConfiguration Provider for Kubernetes

The Azure AppConfiguration provider for Kubernetes is an extension for AKS and installed as part of the Terraform deployment. The provider allows you to use Azure App Configuration as a configuration source for your applications running in Kubernetes. It automates the process of syncing the configuration settings from Azure App Configuration to a Kubernetes ConfigMap.

> [!WARNING]
> The AKS extension will do the Helm install of the AppConfiguration provider. This includes creating a user-assigned managed identity in the Node Resource Group and a Kubernetes ServiceAccount with workload identity partially enabled. Currently, it does not create the federated credential nor does it fill in the clientId in the ServiceAccount annotation so we need to configure the remaining bits to allow the Azure AppConfiguration provider to access the Azure App Configuration store using workload identity.

```bash
# Pull the principalId from the AKS extension
AC_IDENTITY_PRINCIPAL_ID=$(az k8s-extension show \
  --cluster-type managedClusters \
  --cluster-name $AKS_NAME \
  --resource-group $RG_NAME \
  --name appconfigurationkubernetesprovider \
  --query aksAssignedIdentity.principalId \
  --output tsv)

# Pull the clientId from the service principal
AC_IDENTITY_CLIENT_ID=$(az ad sp show \
  --id $AC_IDENTITY_PRINCIPAL_ID \
  --query appId \
  --output tsv)

# Pull the resource id from the service principal
AC_IDENTITY_ID=$(az ad sp show \
  --id $AC_IDENTITY_PRINCIPAL_ID \
  --query "alternativeNames[1]" \
  --output tsv)

# Pull the user-assigned managed identity name
AC_IDENTITY_NAME=$(az identity show \
  --ids $AC_IDENTITY_ID \
  --query name \
  --output tsv)

# Pull the user-assigned managed identity resource group name
AC_IDENTITY_RG_NAME=$(az identity show \
  --ids $AC_IDENTITY_ID \
  --query resourceGroup \
  --output tsv)

# Pull the AKS OIDC issuer
AKS_OIDC_ISSUER=$(az aks show \
  --name $AKS_NAME \
  --resource-group $RG_NAME \
  --query oidcIssuerProfile.issuerUrl \
  --output tsv)

# Create the federated credential
az identity federated-credential create \
  --name azappconfig-provider \
  --identity-name $AC_IDENTITY_NAME \
  --resource-group $AC_IDENTITY_RG_NAME \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:azappconfig-system:az-appconfig-k8s-provider \
  --audience api://AzureADTokenExchange

# Patch the ServiceAccount with the clientId
kubectl patch sa -n azappconfig-system az-appconfig-k8s-provider -p "{\"metadata\": {\"annotations\": {\"azure.workload.identity/client-id\": \"${AC_IDENTITY_CLIENT_ID}\"}}}"

# Add a role assignment for the managed identity
az role assignment create \
  --role "App Configuration Data Owner" \
  --scope $AC_ID \
  --assignee-object-id $AC_IDENTITY_PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal
```

Deploy the Azure AppConfiguration provider for Kubernetes:

```bash
kubectl apply -f - <<EOF
apiVersion: azconfig.io/v1
kind: AzureAppConfigurationProvider
metadata:
  name: ai-service-configs
  namespace: pets
spec:
  endpoint: $AC_ENDPOINT
  target:
    configMapName: ai-service-configs
  auth:
    workloadIdentity:
      managedIdentityClientId: $AC_IDENTITY_CLIENT_ID
EOF
```

Check the ConfigMap to see if the configuration settings were loaded:

```bash
kubectl get configmap -n pets ai-service-configs -o yaml
```

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
    - port: 80
      targetPort: http
      name: http
  selector:
    app: ai-service
EOF
```

Create the rollout and note the canary steps. The first step sets the weight to 50% for the canary service. The second step pauses the rollout. The third step sets the weight to 100% for the canary service. The fourth step pauses the rollout and waits for a final promotion.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $OAI_IDENTITY_CLIENT_ID
  name: ai-service-account
  namespace: pets
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ai-service
  namespace: pets
spec:
  replicas: 10
  strategy:
    canary:
      canaryService: ai-service-canary
      stableService: ai-service-stable
      trafficRouting:
        plugins:
          argoproj-labs/gatewayAPI:
            httpRoute: ai-service
            namespace: pets
      steps:
      - setWeight: 50
      - pause: {}
      - setWeight: 100
      - pause: {}
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: ai-service
  template:
    metadata:
      labels:
        app: ai-service
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: ai-service-account
      containers:
        - name: ai-service
          image: ghcr.io/pauldotyu/aks-store-demo/ai-service:1.2.0
          ports:
            - containerPort: 5001
          envFrom:
            - configMapRef:
                name: ai-service-configs
          resources:
            requests:
              cpu: 20m
              memory: 50Mi
            limits:
              cpu: 50m
              memory: 128Mi
          startupProbe:
            httpGet:
              path: /health
              port: 5001
            initialDelaySeconds: 60
            failureThreshold: 3
            periodSeconds: 5
          readinessProbe:
            httpGet:
              path: /health
              port: 5001
            initialDelaySeconds: 3
            failureThreshold: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 5001
            initialDelaySeconds: 3
            failureThreshold: 10
            periodSeconds: 10
EOF
```

Watch the rollout and wait for **Status** to show **✔ Healthy**.

```bash
kubectl argo rollouts get rollout ai-service -n pets -w
```

When the rollout is healthy, hit **CTRL+C** to exit the watch then patch the rollout to change the **ai-service** image to the **1.4.0** version.
  
```bash
kubectl edit rollout ai-service -n pets
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
kubectl get gtw -n aks-istio-ingress gateway
```

If the value for **PROGRAMMED** is not **True**, then take a look at the status conditions for the Gateway:

```bash
kubectl describe gtw -n aks-istio-ingress gateway
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
