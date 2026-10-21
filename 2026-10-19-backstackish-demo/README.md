# BACK-ish stack demo

BACK stack platform engineering demo, but with an Azure twist 😉

## Environment setup

Make sure you have the following prerequisites installed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [jq](https://stedolan.github.io/jq/download/)
- [OpenTofu](https://opentofu.io/docs/getting-started/installation)

### Provision Azure infrastructure

Set up your Terraform variables by copying the example file and filling in the required values:

```sh
cp terraform.tfvars.example terraform.tfvars
```

> Make sure to fill in the required values in `terraform.tfvars` before running Terraform.

Run the Terraform

```sh
terraform init
terraform apply -auto-approve
```

Get the output values

```sh
read -r \
  RG_NAME \
  AKS_NAME \
  DNS_ZONE_NAME \
  DNS_NAME_SERVERS <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .dns_zone_name.value,
      (.dns_name_servers.value | join(" "))] | @tsv')"
```

Print the DNS zone name servers then make sure they are correctly configured in your DNS provider.

```sh
echo "$DNS_NAME_SERVERS" | tr ' ' '\n'
```

> GoDaddy does not want the trailing dot in the DNS zone name servers. Make sure to remove it as you configure it there.

After updating your DNS provider with the name servers, wait for the changes to propagate before proceeding.

```sh
dig +short NS $DNS_ZONE_NAME
```

Connect to the cluster

```sh
az aks get-credentials -n $AKS_NAME -g $RG_NAME
```

### Configure external-dns

Deploy the external-dns resources

```sh
kubectl apply -f kubernetes/external-dns.yaml
```

### Configure cert-manager

Deploy a cert-manager ClusterIssuer resource

```sh
kubectl apply -f kubernetes/cert-manager.yaml
```

Check the status of the ClusterIssuer

```sh
kubectl get clusterissuer
```

### Configure Backstage

Create the namespace for Backstage

```sh
kubectl create namespace backstage
```

Create the secret store and external secrets for Backstage

```sh
kubectl apply -f kubernetes/external-secrets.yaml
```

> Source: [https://external-secrets.io/latest/provider/azure-key-vault/](https://external-secrets.io/latest/provider/azure-key-vault/)

Make sure the secrets have synchronized successfully from Azure Key Vault before proceeding.

```sh
kubectl get secrets -n backstage backstage-secrets -oyaml
```

Install Backstage. The Helm chart will install the CertificateRequest and Gateway resources for Backstage.

```sh
helm upgrade --install backstage oci://ghcr.io/pauldotyu/charts/backstage \
--version 0.1.0-sha-7f877bc \
-n backstage \
-f kubernetes/backstage-values.yaml
```

Check the status of the Backstage gateway

```sh
kubectl get gateway -n backstage backstage
```

Wait a few moments for the gateway to be programmed, then get the IP address to create a DNS record for the Argo CD hostname

```sh
az network dns record-set a show \
--zone-name $DNS_ZONE_NAME \
--resource-group $RG_NAME \
--name backstage
```

Check the status of the certificate

```sh
kubectl get certificate -n backstage backstage-tls
```

Once the certificate is ready, you can access Backstage at `https://backstage.<your-dns-zone-name>`.

> If you encounter an issue logging in, check the Backstage pod logs to make sure the MicrosoftGraphOrgEntityProvider plugin has successfully synchronized users and groups from Microsoft Entra ID.

### Configure Argo CD

Deploy Argo CD certificate request and gateway

```sh
kubectl apply -f kubernetes/argo-cd.yaml
```

Check the status of the Argo CD gateway

```sh
kubectl get gateway -n argocd argocd-gateway
```

Wait a few moments for the gateway to be programmed, then get the IP address to create a DNS record for the Argo CD hostname

```sh
az network dns record-set a show \
--zone-name $DNS_ZONE_NAME \
--resource-group $RG_NAME \
--name argocd
```

Check the status of the certificate

```sh
kubectl get certificate -n argocd argocd-tls
```

Once the certificate is ready, you can access Argo CD at `https://argocd.<your-dns-zone-name>`.

### Configure Crossplane

Deploy the OpenTofu provider for Crossplane

```sh
kubectl apply -f kubernetes/crossplane.yaml
```

Make sure the provider is installed and healthy since the next step will require the existence of OpenTofu custom resource definitions (CRDs).

```sh
kubectl get providers
kubectl wait --for=condition=Healthy provider/provider-opentofu --timeout=60s
```

Configure the OpenTofu provider

```sh
kubectl apply -f kubernetes/opentofu-state.yaml
```

Test the OpenTofu provider configuration with a quick workspace deployment

```sh
kubectl apply -f - <<EOF
apiVersion: opentofu.m.upbound.io/v1beta1
kind: Workspace
metadata:
  name: tofu-test
  annotations:
    crossplane.io/external-name: tofu-test
spec:
  providerConfigRef:
    name: provider-opentofu
    kind: ClusterProviderConfig
  forProvider:
    source: Inline
    module: |
      terraform {
        required_providers {
          azurerm = {
            source  = "hashicorp/azurerm"
            version = "~> 5.0"
          }
        }
      }

      provider "azurerm" {
        features {}
        use_oidc = true
      }

      resource "azurerm_resource_group" "test" {
        name     = "rg-tofu-test"
        location = "westus3"
      }
EOF
```

Check the status of the workspace deployment

```sh
kubectl get workspaces
kubectl describe workspace tofu-test
```

Verify that the workspace has been successfully deployed and the resource group has been created in Azure.

```sh
az group show \
--name rg-tofu-test \
--query '{name:name,location:location,provisioningState:properties.provisioningState}' \
-o yaml
```

Delete the workspace deployment

```sh
kubectl delete workspace tofu-test
```

Verify that the resource group has been deleted in Azure.

```sh
az group show --name rg-tofu-test
```

## Platform setup

Setup the platform API by applying the ArgoCD application manifest:

```sh
kubectl apply -f https://raw.githubusercontent.com/pauldotyu/platform/refs/heads/main/argocd/platform-api.yaml
```

What this does:

- Watches `main`, recursively including anything under api/ to the platform.
- Automatically syncs your XRD and compositions to the platform.
- Restricts this project to only two resource types: CompositeResourceDefinition and Composition.
- Disables automatic pruning so removing an API definition form Git does not automatically delete it from the cluster.

```sh
kubectl -n argocd get application platform-api \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
```

Setup another Argo CD application that recursively checks for changes in the requests/agent-environments directory to build OpenTofu workspaces.

```sh
kubectl apply -f https://raw.githubusercontent.com/pauldotyu/platform/refs/heads/main/argocd/agent-environments.yaml
```

From this point on, navigate to Backstage and import the following templates:

- `https://github.com/pauldotyu/backstage/blob/main/templates/create-agent-environment/template.yaml`
- `https://github.com/pauldotyu/backstage/blob/main/templates/delete-agent-environment/template.yaml`
- `https://github.com/pauldotyu/backstage/blob/main/templates/create-maf-app/template.yaml`

## Teardown

Delete any Crossplane-managed requests and workspaces first, and wait for their external Azure resources to be deleted while the providers are still running.

Uninstall Backstage and delete its ExternalSecret and SecretStore while External Secrets Operator is still running. These resources were installed manually, so Terraform does not manage their deletion order.

```sh
helm uninstall backstage -n backstage
kubectl delete -f kubernetes/external-secrets.yaml --timeout=120s
```

If deletion times out, resolve the operator or finalizer issue before continuing. Check for other ExternalSecrets and SecretStores and remove any demo resources that still require operator cleanup.

```sh
kubectl get externalsecrets.external-secrets.io,secretstores.external-secrets.io -A
```

Then destroy the Terraform-managed infrastructure:

```sh
terraform destroy
```

The External Secrets Helm release retains its CRDs using `helm.sh/resource-policy: keep`. This prevents Helm from deleting CRDs and their custom resources at the same time as the operator responsible for processing their finalizers. cert-manager also retains its CRDs. Helm information messages about these retained resources are expected. When destroying the whole AKS cluster, the retained CRDs disappear with the cluster.

For an existing deployment, apply the retention setting with `terraform apply` before uninstalling the release. Changing the configuration alone does not update the installed Helm release.

### External Secrets uninstall timeout

If an uninstall has already removed the operator, check whether an ExternalSecret and its CRD are stuck deleting:

```sh
kubectl get crd externalsecrets.external-secrets.io \
  -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.status.conditions}{"\n"}'
kubectl get externalsecrets.external-secrets.io -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,FINALIZERS:.metadata.finalizers'
kubectl get pods -n external-secrets
```

A terminating CRD with `InstanceDeletionInProgress` and an ExternalSecret with `externalsecrets.external-secrets.io/externalsecret-cleanup` indicate unfinished operator cleanup. Increasing the Helm timeout will not resolve an orphaned finalizer when the operator is gone.

The retention setting prevents this deletion race on future uninstalls, but does not repair a CRD already terminating. Recovery requires restoring an operator capable of completing cleanup or explicitly approving targeted removal of the orphaned finalizer after reviewing its cleanup responsibilities. Removing a finalizer bypasses that cleanup and may leave generated Kubernetes Secrets behind. Do not remove the CRD's cleanup finalizer or delete Terraform state to hide the failure.

## Resources

- [Azure AKS App Routing with Gateway API, DNS, and TLS](https://learn.microsoft.com/azure/aks/app-routing-gateway-api-dns-tls)
