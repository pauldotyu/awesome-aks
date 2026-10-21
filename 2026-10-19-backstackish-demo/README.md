# BACK-ish stack demo

## Environment setup

Make sure you have the following prerequisites installed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [jq](https://stedolan.github.io/jq/download/)
- [OpenTofu](https://opentofu.io/docs/getting-started/installation)

### Provision Azure infrastructure

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
  DNS_ZONE_NAME <<< "$(terraform output -json | jq -r \
    '[.rg_name.value,
      .aks_name.value,
      .dns_zone_name.value] | @tsv')"
```

Connect to the cluster

```sh
az aks get-credentials -n $AKS_NAME -g $RG_NAME
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

Install Backstage. The Helm chart will install the CertificateRequest and Gateway resources for Backstage.

```sh
helm upgrade --install backstage oci://ghcr.io/pauldotyu/charts/backstage \
--version 0.1.0-sha-6f1a9fd \
-n backstage \
-f kubernetes/backstage-values.yaml
```

Check the status of the Backstage gateway

```sh
kubectl get gateway -n backstage backstage
```

Wait a few moments for the gateway to be programmed, then get the IP address to create a DNS record for the Argo CD hostname

```sh
az network dns record-set a add-record \
--zone-name $DNS_ZONE_NAME \
--resource-group $RG_NAME \
--record-set-name backstage \
--ipv4-address $(kubectl get gateway -n backstage backstage -ojsonpath='{.status.addresses[0].value}')
```

Check the status of the certificate

```sh
kubectl get certificate -n backstage backstage-tls
```

Once the certificate is ready, you can access Backstage at `https://backstage.paulyu.rocks`.

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
az network dns record-set a add-record \
--zone-name $DNS_ZONE_NAME \
--resource-group $RG_NAME \
--record-set-name argocd \
--ipv4-address $(kubectl get gateway -n argocd argocd-gateway -ojsonpath='{.status.addresses[0].value}')
```

Check the status of the certificate

```sh
kubectl get certificate -n argocd argocd-tls
```

Once the certificate is ready, you can access Argo CD at `https://argocd.paulyu.rocks`.

### Configure Crossplane

Deploy the OpenTofu provider for Crossplane

```sh
kubectl apply -f kubernetes/crossplane.yaml
```

Make sure the provider is installed and healthy since the next step will require the existence of OpenTofu custom resource definitions (CRDs).

```sh
kubectl get providers
kubectl wait --for=condition=Healthy provider provider-opentofu --timeout=60s
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
  name: tofu-azure-rg-test
  annotations:
    crossplane.io/external-name: tofu-azure-rg-test
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
        name     = "rg-tofu-crossplane-test"
        location = "westus3"
      }
EOF
```

Check the status of the workspace deployment

```sh
kubectl get workspaces
kubectl describe workspace tofu-azure-rg-test
```

Verify that the workspace has been successfully deployed and the resource group has been created in Azure.

```sh
az group show \
--name rg-tofu-crossplane-test \
--query '{name:name,location:location,provisioningState:properties.provisioningState}' \
-o yaml
```

Delete the workspace deployment

```sh
kubectl delete workspace tofu-azure-rg-test
```

Verify that the resource group has been deleted in Azure.

```sh
az group show --name rg-tofu-crossplane-test
```

### Validate Crossplane + OpenTofu integration

```sh
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: xresourcegroup.platform.example.org
spec:
  group: platform.example.org
  names:
    kind: XResourceGroup
    plural: xresourcegroups
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - parameters
            properties:
              parameters:
                type: object
                required:
                - name
                - location
                - requesterObjectId
                properties:
                  name:
                    type: string
                    pattern: '^rg-[a-z0-9-]{1,60}$'
                  location:
                    type: string
                  requesterObjectId:
                    type: string
                    minLength: 1
EOF
```

```sh
kubectl apply -f - <<'EOF'
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: resource-group
spec:
  compositeTypeRef:
    apiVersion: platform.example.org/v1alpha1
    kind: XResourceGroup
  mode: Pipeline
  pipeline:
  - step: render-opentofu-workspace
    functionRef:
      name: function-go-templating
    input:
      apiVersion: gotemplating.fn.crossplane.io/v1beta1
      kind: GoTemplate
      source: Inline
      inline:
        template: |
          apiVersion: opentofu.m.upbound.io/v1beta1
          kind: Workspace
          metadata:
            annotations:
              gotemplating.fn.crossplane.io/composition-resource-name: opentofu-workspace
          spec:
            providerConfigRef:
              kind: ClusterProviderConfig
              name: provider-opentofu
            forProvider:
              source: Remote
              module: github.com/pauldotyu/crossplane-opentofu-demo//modules/resource-group?ref=main
              vars:
              - key: resource_group_name
                value: {{ .observed.composite.resource.spec.parameters.name | quote }}
              - key: location
                value: {{ .observed.composite.resource.spec.parameters.location | quote }}
              - key: requester_object_id
                value: {{ .observed.composite.resource.spec.parameters.requesterObjectId | quote }}
  - step: automatically-detect-ready
    functionRef:
      name: function-auto-ready
EOF
```

```sh
REQUESTER_OBJECT_ID=$(az ad signed-in-user show --query id -otsv)

kubectl apply -f - <<EOF
apiVersion: platform.example.org/v1alpha1
kind: XResourceGroupRequest
metadata:
  name: rg-demo
spec:
  parameters:
    name: rg-demo
    location: westus3
    requesterObjectId: "${REQUESTER_OBJECT_ID}"
EOF
```

```sh
kubectl wait --for=condition=Ready xresourcegrouprequest rg-demo --timeout=300s
```

```sh
kubectl describe xresourcegrouprequest rg-demo
kubectl get workspace
```

```sh
az group show \
--name rg-demo \
--query '{name:name,location:location,provisioningState:properties.provisioningState}' \
-o yaml
```

```sh
kubectl delete xresourcegrouprequest rg-demo
```

```sh
az group show --name rg-demo
```

## Platform setup

Setup the platform API by applying the ArgoCD application manifest:

```sh
kubectl apply -f https://raw.githubusercontent.com/pauldotyu/crossplane-opentofu-demo/refs/heads/main/argocd/platform-api.yaml
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
kubectl apply -f https://raw.githubusercontent.com/pauldotyu/crossplane-opentofu-demo/refs/heads/main/argocd/agent-environments.yaml
```

From this point on, navigate to Backstage and import the following templates:

- [https://github.com/pauldotyu/backstage/blob/main/templates/create-agent-environment/template.yaml](https://github.com/pauldotyu/backstage/blob/main/templates/create-agent-environment/template.yaml)
- [https://github.com/pauldotyu/backstage/blob/main/templates/delete-agent-environment/template.yaml](https://github.com/pauldotyu/backstage/blob/main/templates/delete-agent-environment/template.yaml)
- [https://github.com/pauldotyu/backstage/blob/main/templates/create-maf-app/template.yaml](https://github.com/pauldotyu/backstage/blob/main/templates/create-maf-app/template.yaml)

## Teardown

Delete any Crossplane-managed requests and workspaces first, and wait for their
external Azure resources to be deleted while the providers are still running.

Uninstall Backstage and delete its ExternalSecret and SecretStore while External
Secrets Operator is still running. These resources were installed manually, so
Terraform does not manage their deletion order.

```sh
helm uninstall backstage -n backstage
kubectl delete -f kubernetes/external-secrets.yaml --timeout=120s
```

If deletion times out, resolve the operator or finalizer issue before continuing.
Check for other ExternalSecrets and SecretStores and remove any demo resources
that still require operator cleanup.

```sh
kubectl get externalsecrets.external-secrets.io,secretstores.external-secrets.io -A
```

Then destroy the Terraform-managed infrastructure:

```sh
terraform destroy
```

The External Secrets Helm release retains its CRDs using
`helm.sh/resource-policy: keep`. This prevents Helm from deleting CRDs and their
custom resources at the same time as the operator responsible for processing
their finalizers. cert-manager also retains its CRDs. Helm information messages
about these retained resources are expected. When destroying the whole AKS
cluster, the retained CRDs disappear with the cluster.

For an existing deployment, apply the retention setting with `terraform apply`
before uninstalling the release. Changing the configuration alone does not update
the installed Helm release.

### External Secrets uninstall timeout

If an uninstall has already removed the operator, check whether an ExternalSecret
and its CRD are stuck deleting:

```sh
kubectl get crd externalsecrets.external-secrets.io \
  -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.status.conditions}{"\n"}'
kubectl get externalsecrets.external-secrets.io -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,DELETING:.metadata.deletionTimestamp,FINALIZERS:.metadata.finalizers'
kubectl get pods -n external-secrets
```

A terminating CRD with `InstanceDeletionInProgress` and an ExternalSecret with
`externalsecrets.external-secrets.io/externalsecret-cleanup` indicate unfinished
operator cleanup. Increasing the Helm timeout will not resolve an orphaned
finalizer when the operator is gone.

The retention setting prevents this deletion race on future uninstalls, but does
not repair a CRD already terminating. Recovery requires restoring an operator
capable of completing cleanup or explicitly approving targeted removal of the
orphaned finalizer after reviewing its cleanup responsibilities. Removing a
finalizer bypasses that cleanup and may leave generated Kubernetes Secrets behind.
Do not remove the CRD's cleanup finalizer or delete Terraform state to hide the
failure.
