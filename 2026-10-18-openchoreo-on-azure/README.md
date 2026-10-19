# OpenChoreo control plane on AKS with Microsoft Entra ID

A production-shaped, disposable test environment that provisions an AKS cluster and installs the **OpenChoreo v1.3.1 control plane** with **Microsoft Entra ID** as the external OIDC provider.

There is **no ThunderID**. Authentication and authorization are entirely Entra-native:

| Concern               | Mechanism                                                                              |
| --------------------- | -------------------------------------------------------------------------------------- |
| User sign-in          | Entra ID (v2.0 endpoints) as OIDC provider for the Backstage console                   |
| User authorization    | `groups` claim in the **access token** → Entra group object id                         |
| Service authorization | `azp` claim (Entra v2 "authorized party") → service client id                          |
| Public TLS            | Let's Encrypt via cert-manager DNS-01 against Azure DNS, using Azure Workload Identity |
| Secret store          | Azure Key Vault + External Secrets Operator (replaces the upstream OpenBao path)       |

Only the **control plane** is installed. There is no data plane, workflow plane, observability plane, OpenBao, ThunderID, or sample workload.

## What Terraform creates

**Azure**

- Resource group, Azure Key Vault, and Terraform-managed A records for `console.aks.rocks` / `api.aks.rocks` in the existing Azure DNS zone
- AKS cluster: single system node pool (1 node), Kubernetes 1.36+, OIDC issuer + Workload Identity enabled, system-assigned identity
- User-assigned managed identity `cert-manager-dns01` — DNS Zone Contributor scoped to the DNS zone only
- User-assigned managed identity `external-secrets` — Key Vault Secrets User scoped to the vault only
- Federated identity credentials for both, bound to the AKS OIDC issuer
- The A records point at the control-plane kgateway LoadBalancer public IP

**Microsoft Entra ID**

- `openchoreo-api` — single tenant, app id uri `api://openchoreo-api`, delegated scope `access_as_user`, app role `OpenChoreo.Access` (Application member type), `ApplicationGroup` group-membership claim, access-token optional claims (`groups`, `email`, `given_name`, `family_name`)
- `openchoreo-backstage` — single-tenant confidential web client for interactive sign-in
- `openchoreo-backstage-service` — single-tenant confidential client for client credentials
- App-role assignments: the platform-engineer Entra group and the service client → `OpenChoreo.Access`

**Cluster**

- Gateway API CRDs v1.5.1, kgateway CRDs + kgateway 2.4.7 (`openchoreo-control-plane`)
- cert-manager v1.19.4 with Azure Workload Identity
- Two Let's Encrypt `ClusterIssuer`s: `letsencrypt-azure-dns-staging` and `letsencrypt-azure-dns-production`
- `cp-gateway-tls` certificate (console + api, pre-provisioned for the data/observability planes)
- External Secrets Operator 2.0.1 + `ClusterSecretStore` + `ExternalSecret` → `backstage-secrets`
- OpenChoreo control plane 1.3.1 (installed only after every prerequisite is verified ready)

## File layout

```text
2026-10-18-openchoreo-on-azure/
├── versions.tf            # provider constraints (match the repo's most recent examples)
├── providers.tf           # azurerm + helm providers
├── variables.tf           # all inputs, with defaults
├── locals.tf              # derived names, OIDC URLs, values context
├── main.tf                # data sources, resource group, kubeconfig file
├── aks.tf                 # AKS cluster + RBAC
├── dns.tf                 # Azure DNS zone
├── entra.tf               # the three Entra apps, SPs, secrets, app roles, group
├── cert-manager.tf        # cert-manager WIF, helm install, both ClusterIssuers
├── key-vault.tf           # Azure Key Vault + the four secret values + ESO WIF
├── external-secrets.tf    # ESO helm install, ClusterSecretStore, ExternalSecret
├── openchoreo.tf          # namespace, Gateway API CRDs, kgateway, cp-gateway-tls, install, DNS
├── outputs.tf             # useful outputs (no secret values)
├── terraform.tfvars.example # points at the pre-existing Azure DNS zone
├── files/
│   ├── control-plane-values.yaml.tpl      # OpenChoreo values (schema-validated against v1.3.1)
│   ├── letsencrypt-clusterissuers.yaml.tpl # both ClusterIssuers
│   ├── cp-gateway-tls.yaml.tpl            # the control-plane Certificate
│   ├── backstage-secrets.yaml.tpl         # ClusterSecretStore + ExternalSecret
│   ├── apply-gateway-api-crd.sh
│   ├── create-namespace.sh
│   ├── kubectl-apply.sh                   # apply a manifest, optionally wait for a condition
│   ├── install-openchoreo.sh              # waits for prerequisites, then installs
│   └── create-dns-records.sh              # waits for the LoadBalancer IP, then creates A records
└── README.md
```

> **Why `kubectl` + `local-exec` instead of the Kubernetes Terraform provider?** The Kubernetes provider needs a live cluster connection at _plan_ time, but the AKS cluster is created by this same apply — so every `kubernetes_*` resource fails to plan on a fresh run (`Failed to construct REST client: no client config`). The `terraform_data` + `kubectl` pattern used here is the one already established in this repo (see `2023-10-19-build-ai-day-london/appconfig.tf`). Because the whole cluster is destroyed together, the applied objects do not need to be tracked individually in Terraform state.

## Prerequisites

- Azure CLI authenticated to the target subscription (`az login`)
- Terraform >= 1.10, kubectl, Helm, jq, **git** and `kubectl`/`helm` on `PATH` (the `terraform_data` steps shell out; `git` is needed for kubectl's built-in kustomize to fetch the Gateway API CRDs)
- An **existing Azure DNS zone** for the public domain (`aks.rocks` here) with the domain's registrar nameservers **already delegated** to it — see [Using the existing Azure DNS zone](#using-the-existing-azure-dns-zone) and [Which subscription gets what](#which-subscription-gets-what)
- An existing Entra group named `CloudNative` (override with `var.platform_engineer_group_display_name`)
- An authenticated `az` session **in the Entra tenant** for the one-time consent step (see below)

## Required Azure / Entra permissions

The identity running Terraform needs:

- `Microsoft.Resources/subscriptions/resourceGroups/write` — create the resource group
- `Microsoft.ContainerService/managedClusters/write` — create AKS
- `Microsoft.Network/dnsZones/write` — create the DNS zone and A records
- `Microsoft.KeyVault/vaults/write` — create the vault
- `Microsoft.ManagedIdentity/userAssignedIdentities/write` — create the two UAIMs
- `Microsoft.Authorization/roleAssignments/write` — assign the DNS Zone Contributor and Key Vault Secrets User roles
- `Microsoft.Authorization/managedIdentity/federatedIdentityCredentials/write` — create the federated credentials
- Entra: `Application.ReadWrite.All` (create the app registrations), `AppRoleAssignment.ReadWrite.All` (assign the app role), and **Application Administrator / Cloud Application Administrator** for the admin-consent step

## Using the existing Azure DNS zone

The zone is expected to already exist with the domain's registrar nameservers delegated to it, so **no delegation step is needed**. Terraform looks the zone up and only manages the A records inside it.

Copy the example variables and point them at your zone:

```bash
cp terraform.tfvars.example terraform.tfvars
```

```hcl
dns_zone_resource_group_name = "rg-blog"
dns_zone_subscription_id     = "<subscription holding the zone>"
```

The zone often lives in a **different subscription** than the cluster (a shared/connectivity subscription is common). `var.dns_zone_subscription_id` handles that — the `azurerm.dns` provider alias targets that subscription, cert-manager's DNS-01 solver is given that `subscriptionID` and `resourceGroupName`, and the A records are created there. Leave `dns_zone_subscription_id` empty if the zone is in the current subscription.

To find your zone:

```bash
az network dns zone list --query "[?name=='aks.rocks'].{rg:resourceGroup,id:id}" -o tsv
```

Confirm the delegation is in place:

```bash
dig +short NS aks.rocks.
```

The four nameservers must be Azure DNS. You can also cross-check against the zone itself:

```bash
terraform output -json dns_zone_nameservers | jq -r '.[]'
```

> If the zone genuinely does not exist yet, set `var.create_dns_zone = true` and Terraform will create it in the new resource group — but then you must delegate the nameservers at the registrar yourself before requesting a production certificate.

### Which subscription gets what

The environment and the pre-existing DNS zone live in **different subscriptions**, and only two writes ever touch the zone's subscription.

| Where                                                      | What                                                                                                                                                                                               |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Environment subscription** (`var.subscription_id`)       | Resource group, AKS cluster, Key Vault + its secrets, both managed identities, federated credentials, the `aks_admin` and `external_secrets_kv` role assignments, and every Entra app registration |
| **DNS zone subscription** (`var.dns_zone_subscription_id`) | The **DNS Zone Contributor** role assignment for cert-manager, and the `console`/`api` A records — nothing else                                                                                    |

Both zone-subscription writes are attachments to the zone you already own, not environment infrastructure. An Azure RBAC assignment is a child resource of its scope, so the cert-manager role necessarily lives alongside the zone; and the A records must live in the zone the domain's nameservers are delegated to.

`var.subscription_id` is pinned explicitly, so the environment cannot drift into the zone's subscription even if the Azure CLI default changes.

If you want **nothing at all** written to the zone's subscription, switch off both:

```bash
terraform apply \
  -var="manage_cert_manager_dns_role=false" \
  -var="manage_dns_a_records=false"
```

You then grant DNS access and create the records yourself:

```bash
# 1. DNS Zone Contributor for the cert-manager identity, on the zone
CERT_MANAGER_OBJECT_ID=$(az identity show --subscription <env-sub> --resource-group <env-rg> \
  -n cert-manager-dns01 --query principalId -o tsv)

az role assignment create \
  --subscription <zone-sub> \
  --role "DNS Zone Contributor" \
  --assignee-object-id "$CERT_MANAGER_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/<zone-sub>/resourceGroups/<zone-rg>/providers/Microsoft.Network/dnsZones/aks.rocks"

# 2. The A records, once the control-plane LoadBalancer has an IP
az network dns record-set a add-record \
  --subscription <zone-sub> --resource-group <zone-rg> --zone-name aks.rocks \
  --record-set-name console --ipv4-address <LB-IP>
az network dns record-set a add-record \
  --subscription <zone-sub> --resource-group <zone-rg> --zone-name aks.rocks \
  --record-set-name api --ipv4-address <LB-IP>
```

Without step 1 cert-manager cannot solve the DNS-01 challenge, and without step 2 the hostnames do not resolve.

### cert-manager writing to a zone in another resource group and subscription

This is the part most likely to look wrong, so to be explicit about it: **it works, and the different resource group is not a problem.**

cert-manager's Azure DNS solver takes the zone's _own_ coordinates — `subscriptionID`, `resourceGroupName` and `hostedZoneName` — and locates the zone with them. `resourceGroupName` means "the resource group the DNS zone is located in", not the resource group the identity lives in. The rendered solver is therefore:

```yaml
solvers:
  - dns01:
      azureDNS:
        subscriptionID: 9445bf79-e177-49e7-9ce3-a831ca9461ae # the zone's subscription
        resourceGroupName: rg-blog # the zone's resource group
        hostedZoneName: aks.rocks # the zone
        environment: AzurePublicCloud
        managedIdentity:
          clientID: <cert-manager UAMI client id>
```

Two things make the cross-subscription path work:

- **Authentication** is Entra-level, not subscription-level. The `cert-manager-dns01` identity lives in the environment subscription, but a federated credential is a tenant-wide object, so the token it mints is valid in any subscription in the tenant.
- **Authorization** is granted on the zone itself. The `DNS Zone Contributor` role assignment is scoped to `.../dnsZones/aks.rocks` in the zone's subscription — not the resource group, not the subscription, just the one zone. Least privilege, and it is the only thing in that subscription that isn't one of the A records.

The `_acme-challenge` TXT records are written inside the `aks.rocks` zone (e.g. `_acme-challenge.aks.rocks`, `_acme-challenge.apps.aks.rocks`), so the single zone-scoped role covers every name in the certificate.

One timing detail: Azure RBAC takes a short while to propagate after the assignment is created, so the very first challenge attempt can fail. Terraform orders the Certificate strictly after the role assignment for that reason, and cert-manager retries the challenge until it succeeds — the install step waits up to 10 minutes for `cp-gateway-tls` to become `Ready`.

## Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> Run `cp terraform.tfvars.example terraform.tfvars` first so Terraform can find the existing DNS zone and pin the environment subscription.

`terraform apply` provisions Azure + Entra, then installs the cluster components in dependency order. The final install step is deliberately gated: it waits until `cp-gateway-tls` is `Ready` and `backstage-secrets` has all four keys before running `helm upgrade --install openchoreo-control-plane`.

The cluster is pinned to **Kubernetes 1.36+** via `var.kubernetes_version` — the minor alias `"1.36"` resolves to the latest GA 1.36.x patch (currently 1.36.4 in `westus3`), so the cluster stays on 1.36+ while still picking up patch updates. Set it to `"1.37"` to move up, or to `null` to track the AKS default.

### One-time Entra step (required)

The `azuread` provider cannot declare an arbitrary delegated OAuth 2.0 scope, nor perform admin consent. Two steps must be run once, in the target tenant:

```bash
# 1) Declare the access_as_user delegated scope on the openchoreo-api app and
#    admin-consent it tenant-wide so single-tenant users can obtain an access
#    token for api://openchoreo-api.
API_APP_ID=$(az ad app list --display-name "openchoreo-api-*" --query "[0].id" -o tsv)
az ad app update --id "$API_APP_ID" \
  --set 'oauth2PermissionScopes=[{"value":"access_as_user","id":"11111111-2222-3333-4444-555555555555","isEnabled":true,"type":"Delegated","description":"Allow the application to access OpenChoreo on behalf of a signed-in user.","userConsentDisplayName":"Access OpenChoreo","userConsentDescription":"Allow this application to access OpenChoreo on your behalf.","administrativeConsentDisplayName":"Access OpenChoreo","administrativeConsentDescription":"Allow this application to access OpenChoreo on behalf of users of the organization."}]'
az ad app permission admin-consent --id "$API_APP_ID"
```

> The scope `id` must be a UUID. Use any stable one you like; it is referenced by the app, not by Terraform. Terraform can run these for you by setting `var.enable_azure_cli_entra_steps = true` (requires an authenticated `az` session in the tenant at apply time).

### Switch Let's Encrypt from staging to production

Both `ClusterIssuer`s always exist. Only the one selected by `var.letsencrypt_environment` backs `cp-gateway-tls`.

```bash
# staging (default) -> the certificate is NOT publicly trusted
terraform apply -var="letsencrypt_environment=staging"

# production -> publicly trusted certificate
terraform apply -var="letsencrypt_environment=production"
```

After switching, cert-manager re-issues `cp-gateway-tls` from the production ACME endpoint. Verify the issuer in the certificate:

```bash
kubectl get secret cp-gateway-tls -n openchoreo-control-plane -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -issuer -subject -ext subjectAltName
```

`issuer=O=Let's Encrypt, CN=R11` means production; `CN=STAGING` means staging.

> Do not request a production certificate before the DNS delegation has propagated, or Let's Encrypt will fail the DNS-01 challenge and burn rate limits.

## Get kubeconfig

Terraform writes the generated kubeconfig into the working directory and exposes it as an output:

```bash
terraform output -json kubeconfig_filename | jq -r '.'
export KUBECONFIG=$(terraform output -json kubeconfig_filename | jq -r '.')
```

Or use Azure CLI directly (this also grants your user cluster-admin via the `Azure Kubernetes Service RBAC Cluster Admin` role assignment Terraform creates):

```bash
az aks get-credentials --resource-group "$(terraform output -rg_name)" --name "$(terraform output -aks_name)"
```

## Verify

### Control-plane LoadBalancer and DNS

```bash
kubectl get svc gateway-default -n openchoreo-control-plane
kubectl get gateway gateway-default -n openchoreo-control-plane -o wide

dig +short console.aks.rocks
dig +short api.aks.rocks
```

The A records are created in the zone's own subscription, so check them there:

```bash
az network dns record-set a list \
  --subscription "$(terraform output -json dns_zone_subscription_id | jq -r '.')" \
  --resource-group "$(terraform output -json dns_zone_resource_group_name | jq -r '.')" \
  --zone-name "$(terraform output -json dns_zone_name | jq -r '.')" \
  -o table
```

Both names must resolve to the LoadBalancer's public IP, and the cert must be served:

```bash
curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://console.aks.rocks
```

### Certificate readiness

```bash
kubectl get certificate -n openchoreo-control-plane
kubectl wait --for=condition=Ready certificate/cp-gateway-tls -n openchoreo-control-plane --timeout=60s
```

### Entra sign-in

Open <https://console.aks.rocks>. Backstage redirects to `login.microsoftonline.com` and returns to the exact callback URI `https://console.aks.rocks/api/auth/openchoreo-auth/handler/frame`.

### Inspect a decoded access token and validate `iss`, `aud`, `groups` and `azp`

**User token (delegated).** Sign in through the console, then copy the access token out of the browser session (or mint one directly):

```bash
TENANT_ID=$(terraform output -json tenant_id | jq -r '.')
API_CLIENT_ID=$(terraform output -json openchoreo_api_client_id | jq -r '.')
GROUP_OBJECT_ID=$(terraform output -json platform_engineer_group_object_id | jq -r '.')

# device-code flow (no client secret needed for a delegated token)
az login --tenant "$TENANT_ID" --allow-no-subscriptions
ACCESS_TOKEN=$(az account get-access-token \
  --tenant "$TENANT_ID" \
  --scope "api://openchoreo-api/access_as_user" \
  --query accessToken -o tsv)

echo "$ACCESS_TOKEN" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq '{
  iss, aud, azp, oid, groups, tid, scp
}'
```

Validate the claims you care about:

```bash
echo "$ACCESS_TOKEN" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq -e \
  --arg iss "https://login.microsoftonline.com/$TENANT_ID/v2.0" \
  --arg aud "$API_CLIENT_ID" \
  --arg grp "$GROUP_OBJECT_ID" '
  { iss_ok:  (.iss == $iss),
    aud_ok:  (.aud == $aud),
    groups_ok: (.groups // [] | index($grp) != null) }'
```

Expected: `iss_ok`, `aud_ok` and `groups_ok` are all `true`.

**Service token (client credentials).** The Backstage service client:

```bash
SERVICE_CLIENT_ID=$(terraform output -json openchoreo_backstage_service_client_id | jq -r '.')
# The service secret lives in Azure Key Vault (not in Terraform state):
SERVICE_SECRET=$(az keyvault secret show \
  --vault-name "$(terraform output -json key_vault_uri | jq -r '.' | sed -E 's#https://(.*)\.vault\.azure\.net#\1#')" \
  --name backstage-service-client-secret --query value -o tsv)

SERVICE_TOKEN=$(curl -sS -X POST \
  "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=$SERVICE_CLIENT_ID" \
  -d "client_secret=$SERVICE_SECRET" \
  -d "scope=api://openchoreo-api/.default" | jq -r .access_token)

echo "$SERVICE_TOKEN" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | jq '{
  iss, aud, azp, idtyp, groups
}'
```

Expected: `aud` is the `openchoreo-api` application id, `azp` equals the service client id, and `idtyp` is `app`.

> The `azp` claim is Entra v2's "authorized party" — the client the token was issued to. This is why OpenChoreo's service_account entitlement uses `azp` and **not** `client_id`.

## OpenChoreo values that were verified against the pinned v1.3.1 chart

Every key path below was checked against the chart's own `values.schema.json` and the rendered output of `helm template` against `oci://ghcr.io/openchoreo/helm-charts/openchoreo-control-plane:1.3.1`.

| Value                                                                                     | Status                                                                                                   |
| ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `openchoreoApi.config.server.publicUrl`                                                   | verified                                                                                                 |
| `openchoreoApi.config.security.subjects.{user,service_account}`                           | verified — schema requires `display_name`, `priority`, `mechanisms.jwt.entitlement.{claim,display_name}` |
| `openchoreoApi.config.security.subjects.service_account.mechanisms.jwt.readable_id_claim` | verified — set to `azp` (chart default is `client_id`)                                                   |
| `openchoreoApi.config.security.authorization.bootstrap.mappings`                          | verified — **nested** shape, see below                                                                   |
| `openchoreoApi.http.hostnames`                                                            | verified                                                                                                 |
| `backstage.{secretName,baseUrl,http.hostnames}`                                           | verified                                                                                                 |
| `backstage.auth.{clientId,oidcScope,scope,serviceClientId,serviceClientSecretKey}`        | verified                                                                                                 |
| `backstage.auth.redirectUrls`                                                             | **schema-valid but inert in v1.3.1** — see below                                                         |
| `security.oidc.{issuer,wellKnownEndpoint,jwksUrl,authorizationUrl,tokenUrl}`              | verified — `wellKnownEndpoint` becomes `OPENCHOREO_AUTH_METADATA_URL`                                    |
| `security.jwt.audience`                                                                   | verified — becomes the API's `security.authentication.jwt.audiences` list                                |
| `gateway.tls.{enabled,hostname,certificateRefs}`                                          | verified — renders `mode: Terminate` + `certificateRefs: [Secret/cp-gateway-tls]`                        |

### `bootstrap.mappings` uses a nested shape

The generic shape `claim`/`value`/`role` at the top level of a mapping is **not** what v1.3.1 expects, and would be silently dropped. The chart renders bindings from:

```yaml
mappings:
  - name: <binding name>
    kind: ClusterAuthzRoleBinding
    entitlement:
      claim: <jwt claim>
      value: <claim value>
    effect: allow
    roleMappings:
      - roleRef:
          kind: ClusterAuthzRole
          name: <role name>
```

This produces:

```yaml
kind: ClusterAuthzRoleBinding
metadata:
  name: platform-engineer-cloudnative
spec:
  roleMappings:
    - roleRef: { name: platform-engineer, kind: ClusterAuthzRole }
  entitlement: { claim: "groups", value: "<entra group object id>" }
  effect: "allow"
```

### `backstage.auth.redirectUrls` is accepted but not rendered

`backstage.auth.redirectUrls` exists in the v1.3.1 schema but **no template in the chart reads it**. The effective redirect URI is derived at runtime from `backstage.baseUrl` as `<baseUrl>/api/auth/openchoreo-auth/handler/frame`, which is exactly the required callback. The value is still supplied in the template for clarity and forward-compatibility. The Entra app's `web.redirect_uris` is the authoritative registration.

### `access_as_user` scope declaration

The `azuread` provider has no first-class resource for declaring a _delegated_ OAuth 2.0 scope on an existing app, and no resource for admin consent. The scope is therefore declared out of band (see "One-time Entra step"). Everything else about the three app registrations — including the `OpenChoreo.Access` **app role** — is declared natively in `entra.tf`.

## Known limitations and next steps

- **kgateway 2.4.7 is required for Kubernetes 1.36.** The validated getting-started notes that kgateway **v2.3.1** produces CRD validation errors on Kubernetes 1.36 that block the install, and that **v2.4.7** is the version that supports it. Because this configuration pins Kubernetes to 1.36+, `var.kgateway_version` defaults to **2.4.7**. If you deliberately want kgateway 2.3.1 you must also pin `var.kubernetes_version` below 1.36 — the two defaults cannot be mixed.
- **The API audience is the application _client id_.** `security.jwt.audience` is set to the `openchoreo-api` client id, while the scopes are expressed against the app id uri `api://openchoreo-api`. Entra v2 tokens carry the client id in `aud`; if a token ever carries the app id uri instead, the audience check would need the other value.
- **A single-node cluster** is a deliberate starting point. Scale with `default_node_pool.node_count`, or add `azurerm_kubernetes_cluster_node_pool` blocks.
- **`letsencrypt_email` is empty by default**, so no ACME contact is registered. Set it to receive expiry notices.
- **Client secrets live in Azure Key Vault**, projected into the cluster by ESO. They are never written to Terraform state as outputs, but note that `azurerm_key_vault_secret.value` and `azuread_application_password.value` are still stored in the Terraform state file. Use a remote backend with encryption-at-rest for anything beyond a disposable test environment.
- **`app_role_ids` / `oauth2_permission_scope_ids`** are read-only on `azuread_application`; the app role is declared with a stable `random_uuid` id so assignments can reference it.
- **Next steps for the data plane:** create the `openchoreo-data-plane` namespace, copy the `cluster-gateway-ca` secret, install `oci://ghcr.io/openchoreo/helm-charts/openchoreo-data-plane` at `1.3.1`, issue a `dp-gateway-tls` certificate covering `*.apps.aks.rocks` (already pre-provisioned in `cp-gateway-tls`'s DNS names and on the same DNS-01 issuer path), and register a `ClusterDataPlane` resource. Add `observer.obs.aks.rocks` when an observability plane is introduced.

## Cleanup

```bash
terraform destroy
```

This removes the AKS cluster (and everything in it), the Key Vault and its secrets, the DNS zone, and the three Entra app registrations. The `access_as_user` scope added by the one-time Entra step is removed along with the `openchoreo-api` app.
