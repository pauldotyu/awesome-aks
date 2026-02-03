# Argo CD with Gateway API and Microsoft Entra ID SSO on AKS

This guide provisions a minimal AKS cluster and installs Argo CD with Microsoft Entra ID SSO (OIDC + Azure Workload Identity). It also exposes Argo CD through Gateway API with TLS managed by cert-manager and Azure DNS.

References:

- [Microsoft Entra ID App Registration Auth using OIDC](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft)
- [Argo CD Helm values](https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml)
- [Argo CD Helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)
- [Argo CD Ingress (Gateway example)](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#gateway-example)

Terraform creates:

- Resource group
- Azure DNS zone for your domain
- AKS cluster with OIDC issuer + workload identity enabled
- Microsoft Entra application + service principal for Argo CD SSO
- Federated identity credentials for Argo CD and cert-manager
- User-assigned managed identity for cert-manager with DNS Zone Contributor role
- Helm installs for Argo CD, cert-manager, and Istio (Gateway API support)

## Prerequisites

- Azure CLI authenticated to a subscription
- Terraform installed
- kubectl installed
- Helm installed
- jq installed

Recommended versions:

- Terraform >= 1.6
- kubectl >= 1.28
- Helm >= 3.13

> [!IMPORTANT]
> You must own a publicly registered domain and be able to delegate its nameservers to Azure DNS.

## Provision Azure resources

Initialize Terraform and provision Azure resources:

```bash
terraform init
terraform apply -auto-approve
```

This provisions the AKS cluster and a Microsoft Entra application/service principal for Argo CD SSO. The app registration sets the redirect URI and OIDC settings, and enables group claims for RBAC mapping. A public DNS zone is also created in Azure DNS.

Verify the apply completed successfully before continuing.

Delegate your domain to Azure DNS using the nameservers from Terraform output, then export the outputs for later steps.

```bash
read -r \
  RG_NAME \
  AKS_NAME \
  TENANT_ID \
  SUBSCRIPTION_ID \
  ARGOCD_CLIENT_ID \
  ARGOCD_ADMIN_OBJECT_ID \
  CERT_MANAGER_IDENTITY_CLIENT_ID \
  DNS_NAME \
  USER_EMAIL <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .argocd_app_tenant_id.value,
      .subscription_id.value,
      .argocd_app_client_id.value,
      .argocd_admin_object_id.value,
      .cert_manager_identity_client_id.value,
      .dns_zone_name.value,
      .user_email.value] | @tsv')"
```

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME
```

## Deploy Let's Encrypt ClusterIssuer and Certificate

Create a production ClusterIssuer for DNS-01 validation with Azure DNS, then request a TLS certificate for Argo CD.

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $USER_EMAIL
    profile: tlsserver
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        azureDNS:
          resourceGroupName: $RG_NAME
          subscriptionID: $SUBSCRIPTION_ID
          hostedZoneName: $DNS_NAME
          environment: AzurePublicCloud
          managedIdentity:
            clientID: $CERT_MANAGER_IDENTITY_CLIENT_ID
EOF
```

Request a TLS certificate for Argo CD:

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-tls
  namespace: argocd
spec:
  secretName: argocd-tls
  privateKey:
    rotationPolicy: Always
  commonName: argocd.${DNS_NAME}
  dnsNames:
    - argocd.${DNS_NAME}
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
EOF
```

## Install Gateway API CRDs

Install the Gateway API CRDs required for Gateway and HTTPRoute.

```bash
kubectl apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.4.1"
```

## Configure Argo CD Gateway

Create a Gateway and HTTPRoute to expose the Argo CD server over HTTPS.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: argocd-gateway
  namespace: argocd
  annotations:
    cert-manager.io/issuer: letsencrypt-production
spec:
  gatewayClassName: istio
  infrastructure:
    annotations:
      service.beta.kubernetes.io/port_80_health-probe_protocol: tcp
      service.beta.kubernetes.io/port_443_health-probe_protocol: tcp
      service.beta.kubernetes.io/port_15021_health-probe_protocol: tcp
  listeners:
    - protocol: HTTPS
      port: 443
      name: https
      hostname: "argocd.$DNS_NAME"
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: argocd-tls
EOF
```

Create the HTTPRoute that maps the hostname to the Argo CD server service.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd-httproute
  namespace: argocd
spec:
  parentRefs:
    - name: argocd-gateway
      namespace: argocd
  hostnames:
    - "argocd.${DNS_NAME}"
  rules:
    - backendRefs:
        - name: argo-cd-argocd-server
          port: 80
      matches:
        - path:
            type: PathPrefix
            value: /
EOF
```

Fetch the public IP assigned to the Gateway.

```bash
ARGOCD_GATEWAY_IP=$(kubectl get gateway -n argocd argocd-gateway -ojsonpath='{.status.addresses[0].value}')
```

Wait for the Gateway to be assigned an IP (this can take a few minutes). If it is empty, re-run the command.

Create an A record in Azure DNS for the Argo CD hostname.

```bash
az network dns record-set a add-record \
--zone-name $DNS_NAME \
--resource-group $RG_NAME \
--record-set-name argocd \
--ipv4-address $ARGOCD_GATEWAY_IP
```

## Test Argo CD

Open <https://argocd.$DNS_NAME> and authenticate with Microsoft Entra ID SSO.

If you see a certificate error, wait for the Certificate to become Ready:

```bash
kubectl get certificate -n argocd argocd-tls
```

If the Argo CD UI is not reachable, verify the Gateway status and service:

```bash
kubectl get gateway -n argocd argocd-gateway -o wide
kubectl get svc -n argocd
```

## Cleanup

Delete Azure resources (this also removes the AKS cluster and all Kubernetes resources):

```bash
terraform destroy -auto-approve
```
