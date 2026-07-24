# Headlamp with Gateway API and Microsoft Entra ID SSO on AKS

This guide provisions a minimal AKS cluster and installs [Headlamp](https://headlamp.dev) (in-cluster) with Microsoft Entra ID SSO enabled. It also exposes Headlamp through Gateway API with TLS managed by cert-manager and Azure DNS.

References:

- [Headlamp in-cluster install with Azure Entra ID](https://headlamp.dev/docs/latest/installation/in-cluster/azure-entra-id/)
- [Headlamp TLS termination](https://headlamp.dev/docs/latest/installation/in-cluster/tls/)
- [Headlamp Helm chart](https://github.com/kubernetes-sigs/headlamp/tree/main/charts/headlamp)

Terraform creates:

- Resource group
- Azure DNS zone for your domain
- AKS cluster with OIDC issuer + workload identity enabled, Azure RBAC, and AKS-managed Entra integration
- Microsoft Entra application + service principal for Headlamp SSO
- Federated identity credentials for Headlamp and cert-manager
- User-assigned managed identity for cert-manager with DNS Zone Contributor role
- Helm installs for Headlamp, cert-manager, and Istio (Gateway API support)

## Prerequisites

- Azure CLI authenticated to a subscription
- Terraform installed
- kubectl installed
- Helm installed
- jq installed

Recommended versions:

- Terraform >= 1.15
- kubectl >= 1.35
- Helm >= 4.2

> [!IMPORTANT]
> You must own a publicly registered domain and be able to delegate its nameservers to Azure DNS.

## Provision Azure resources

Initialize Terraform and provision Azure resources:

```bash
terraform init
terraform apply -auto-approve
```

This provisions the AKS cluster and a Microsoft Entra application/service principal for Headlamp SSO. The app registration sets the redirect URI and OIDC settings, and enables group claims for RBAC mapping. A public DNS zone is also created in Azure DNS.

Verify the apply completed successfully before continuing.

Delegate your domain to Azure DNS using the nameservers from Terraform output, then export the outputs for later steps.

```bash
read -r \
  RG_NAME \
  AKS_NAME \
  TENANT_ID \
  SUBSCRIPTION_ID \
  HEADLAMP_APP_CLIENT_ID \
  HEADLAMP_ADMIN_OBJECT_ID \
  CERT_MANAGER_IDENTITY_CLIENT_ID \
  DNS_NAME \
  USER_EMAIL <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .headlamp_app_tenant_id.value,
      .subscription_id.value,
      .headlamp_app_client_id.value,
      .headlamp_admin_object_id.value,
      .cert_manager_identity_client_id.value,
      .dns_zone_name.value,
      .user_email.value] | @tsv')"
```

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME
```

## Deploy Let's Encrypt ClusterIssuer and Certificate

Create a production ClusterIssuer for DNS-01 validation with Azure DNS, then request a TLS certificate for Headlamp.

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

Request a TLS certificate for Headlamp:

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: headlamp-tls
  namespace: headlamp
spec:
  secretName: headlamp-tls
  privateKey:
    rotationPolicy: Always
  commonName: headlamp.${DNS_NAME}
  dnsNames:
    - headlamp.${DNS_NAME}
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
kubectl apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.6.1"
```

## Configure Headlamp Gateway

Create a Gateway and HTTPRoute to expose the Headlamp server over HTTPS.

> [!NOTE]
> Headlamp supports two TLS strategies (see [Headlamp TLS termination](https://headlamp.dev/docs/latest/installation/in-cluster/tls/)):
>
> - **Termination at the gateway (used here):** the Istio Gateway terminates TLS using the cert-manager-issued `headlamp-tls` secret, and forwards plain HTTP to the Headlamp service. The Headlamp backend runs without TLS, so no `tlsCertPath`/`tlsKeyPath` is set in the Helm values.
> - **Passthrough to the backend:** the gateway passes TLS through and the Headlamp container terminates it via `config.tlsCertPath`/`config.tlsKeyPath`. This demo does not use passthrough. If you enable backend TLS, remember to switch the pod's readiness/liveness probes to the `HTTPS` scheme, otherwise the kubelet probes fail the handshake and the pod never becomes Ready.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: headlamp-gateway
  namespace: headlamp
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
      hostname: "headlamp.$DNS_NAME"
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: headlamp-tls
EOF
```

Create the HTTPRoute that maps the hostname to the Headlamp server service.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: headlamp-httproute
  namespace: headlamp
spec:
  parentRefs:
    - name: headlamp-gateway
      namespace: headlamp
  hostnames:
    - "headlamp.${DNS_NAME}"
  rules:
    - backendRefs:
        - name: headlamp
          port: 80
      matches:
        - path:
            type: PathPrefix
            value: /
EOF
```

Fetch the public IP assigned to the Gateway.

```bash
HEADLAMP_GATEWAY_IP=$(kubectl get gateway -n headlamp headlamp-gateway -ojsonpath='{.status.addresses[0].value}')
```

Wait for the Gateway to be assigned an IP (this can take a few minutes). If it is empty, re-run the command.

Create an A record in Azure DNS for the Headlamp hostname.

```bash
az network dns record-set a add-record \
--zone-name $DNS_NAME \
--resource-group $RG_NAME \
--record-set-name headlamp \
--ipv4-address $HEADLAMP_GATEWAY_IP
```

## Test Headlamp

Open `https://headlamp.$DNS_NAME` and authenticate with Microsoft Entra ID SSO.

If you see a certificate error, wait for the Certificate to become Ready:

```bash
kubectl get certificate -n headlamp headlamp-tls
```

If the Headlamp UI is not reachable, verify the Gateway status and service:

```bash
kubectl get gateway -n headlamp headlamp-gateway -o wide
kubectl get svc -n headlamp
```

## Cleanup

Delete Azure resources (this also removes the AKS cluster and all Kubernetes resources):

```bash
terraform destroy -auto-approve
```
