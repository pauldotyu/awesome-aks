# ArgoCD with Microsoft Entra ID SSO on AKS

This guide provisions a minimal AKS cluster and installs Argo CD configured for Microsoft Entra ID SSO using OIDC and Azure Workload Identity.

References:

- [Microsoft Entra ID App Registration Auth using OIDC](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft)
- [Argo CD Helm values](https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml)
- [Argo CD Helm chart](https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd)

Terraform creates:

- Resource group
- AKS cluster with OIDC issuer + workload identity enabled
- Microsoft Entra application + service principal for Argo CD SSO

## Prerequisites

Before you begin, verify the following:

- Azure CLI authenticated to a subscription
- Terraform installed
- kubectl installed
- Helm installed

## Provision Azure resources

Initialize Terraform and provision Azure resources:

```bash
terraform init
terraform apply -auto-approve
```

This provisions the AKS cluster and a Microsoft Entra application and service principal for Argo CD SSO. The app registration establishes the redirect URI and OIDC settings used by Argo CD, and group claims are enabled so you can map Entra group IDs to Argo CD roles via RBAC.

Read the Terraform outputs for use in the next steps. If you plan to use a real DNS name, delegate your DNS zone at your registrar using the nameservers shown by Terraform.

```bash
read -r RG_NAME AKS_NAME TENANT_ID CLIENT_ID ADMIN_GROUP_OBJECT_ID <<< "$(terraform output -json | jq -r '[.rg_name.value,.aks_name.value,.argocd_app_tenant_id.value,.argocd_app_client_id.value,.admin_group_object_id.value] | @tsv')"
```

## Install ArgoCD with Entra SSO

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME
```

Add the Argo Helm repository and update:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Install Argo CD with the Entra SSO configuration:

> [!note]
> This example uses a heredoc to pass inline YAML to `--values`, which keeps the guide self-contained and avoids creating a temporary values file. If you prefer, you can copy the same YAML into a real file (for example, `values.yaml`) and pass it with `--values values.yaml`.

```bash
helm upgrade argocd argo/argo-cd \
--install \
--namespace argocd \
--create-namespace \
--version 9.3.7 \
--values <(cat <<EOF
global:
  domain: argocd.example.com
configs:
  cm:
    admin.enabled: false
    oidc.config: |
      name: Microsoft Entra ID
      issuer: https://login.microsoftonline.com/$TENANT_ID/v2.0
      clientID: $CLIENT_ID
      azure:
        useWorkloadIdentity: true
      requestedIDTokenClaims:
        groups:
          essential: true
          value: "ApplicationGroup"
      requestedScopes:
        - openid
        - profile
        - email
  rbac:
    policy.csv: |
      g, "$ADMIN_GROUP_OBJECT_ID", role:admin
server:
  podLabels:
    azure.workload.identity/use: "true"
  serviceAccount:
    annotations:
      azure.workload.identity/client-id: $CLIENT_ID
  service:
    type: LoadBalancer
EOF
)
```

Helm values explained:

- `global.domain`: Sets the external hostname Argo CD uses when generating URLs. The redirect URI in Microsoft Entra must match the external Argo CD URL. Make sure Helm `global.domain` matches the redirect URI domain.
- `configs.cm.oidc.config`: Defines the OIDC provider (Microsoft Entra ID) and requested scopes/claims.
- `configs.cm.rbac.policy.csv`: Grants Argo CD permissions to a specific Entra group ID.
- `server.podLabels`: Adds the workload identity label so the server pod can use Azure Workload Identity.
- `server.serviceAccount.annotations`: Binds the workload identity client ID to the Argo CD server service account.
- `server.service.type: LoadBalancer`: Exposes the Argo CD server externally via a public IP.

See [Configure Argo to use the new Entra ID App registration](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/microsoft/#configure-argo-to-use-the-new-entra-id-app-registration) for more details on the OIDC configuration options.

## Access ArgoCD

Get the public IP of the Argo CD server:

> [!note]
> This sample uses a public LoadBalancer for the Argo CD server and a local hosts file entry for name resolution. For production, prefer a real DNS record and an HTTPS Ingress.

```bash
PUBLIC_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat <<EOF | sudo tee -a /etc/hosts
${PUBLIC_IP} argocd.example.com
EOF
```

Open your browser and navigate to `https://argocd.example.com`. You can log in with Microsoft Entra ID SSO.
The hosts entry lets your browser resolve the Argo CD hostname to the LoadBalancer IP for testing. In production, replace this with a real DNS record and terminate TLS at an Ingress or gateway.

What this configuration does:

- Enables OIDC authentication in Argo CD and registers Microsoft Entra as the identity provider.
- Uses workload identity on the Argo CD server to acquire tokens without client secrets.
- Sets a consistent external URL and domain to ensure the redirect URI matches the Entra app registration.

## Cleanup

When you are done testing, you can delete the Azure resources (this also removes the AKS cluster and all Kubernetes resources) with:

```bash
terraform destroy -auto-approve
```

Remove the hosts file entry when done:

```bash
sudo sed -i.bak "/${PUBLIC_IP} argocd.example.com/d" /etc/hosts
```
