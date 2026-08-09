# The Developer Experience with AKS Desktop and VS Code

Getting an app from your laptop to a production Kubernetes cluster is full of gaps: you have a container image, but then you need Kubernetes manifests, cluster access, a way to deploy, and answers to the day-2 questions (Is it healthy? Can I do this again next week?). This project stands up the demo environment for my demo in the Azure booth at **KubeCon Japan 2026**, which shows how [AKS Desktop](https://aka.ms/aks/desktop) and the [AKS extension for VS Code](https://learn.microsoft.com/azure/aks/aks-extension-vs-code) close those gaps and make shipping to AKS repeatable.

The session tells one story in three moves, using a single container image ([`contoso-air`](https://github.com/pauldotyu/contoso-air)) with a chat feature wired to Azure AI:

- **Deploy** - AKS Desktop generates Kubernetes manifests and walks you through deploying a container image to AKS, applying built-in Kubernetes best practices along the way.
- **Manage** - Day-2 operations (scaling, logs, RBAC, resource quotas, cost) all from AKS Desktop, including fixing up the app and wiring the chat integration to Azure AI with workload identity.
- **Make repeatable** - The AKS extension for VS Code brings manifest generation, cluster diagnostics, and GitOps setup into your editor, then hands the reconciliation loop off to **Argo CD**.

Terraform provisions all of the Azure-side infrastructure the demo depends on so the session can focus on the developer workflow, not the setup.

## What Terraform creates

Core platform:

- **Resource group** (`rg-devxdemo<xxxx>`) holding everything, named with a random suffix so it is easy to spin up and tear down repeatedly.
- **AKS Automatic cluster** (deployed via AzAPI) with a system-assigned identity, Azure Monitor metrics (managed Prometheus), Container Insights, and OpenTelemetry auto-instrumentation (logs, traces, and metrics) enabled. AKS Automatic gives you a production-ready cluster with best-practice defaults so there is less to configure by hand.
- **AKS managed namespace** (`team-blue`) with an adoption policy, default network policy, and a CPU/memory resource quota. It is labeled for AKS Desktop / Headlamp so the namespace shows up as a project in the UI, and the deploying user is granted the **Namespace Contributor** and **Namespace User** roles.
- **Azure Container Registry** (Standard) with **AcrPull** granted to the cluster's kubelet identity so AKS can pull images without admin credentials.

GitOps and identity:

- **Argo CD** installed as an AKS cluster extension (`Microsoft.ArgoCD`), configured for **Microsoft Entra ID single sign-on** via workload identity. The built-in admin account is disabled and access is driven by Entra group membership instead.
- **Microsoft Entra application** (`myargocdapp`) with a federated identity credential for the `argocd-server` service account, group claims, and Microsoft Graph delegated permissions. An Entra security group (see [entra.tf](./entra.tf)) is mapped to the Argo CD `admin` role through the RBAC policy.

Application integration:

- **Azure AI Services account** (Microsoft Foundry) with **`gpt-5.4-mini`** and **`gpt-image-2`** model deployments, powering the `contoso-air` chat feature.
- **User-assigned managed identity** with a federated identity credential for the `contoso-air-sa` service account in the `team-blue` namespace, plus the **Cognitive Services OpenAI User** role. This lets the app authenticate to Azure AI with **workload identity** instead of API keys.

Observability:

- **Azure Monitor workspace** (managed Prometheus), **Log Analytics workspace**, and an **Application Insights** component with OTLP logs and metrics endpoints for the cluster's OpenTelemetry auto-instrumentation.

## Prerequisites

Install the following tools:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (to inspect the cluster)
- [Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/) (to log in via SSO and confirm access)

Then prepare your Azure and Entra environment:

- Authenticate the Azure CLI to a subscription where you can create AKS clusters, an Azure Container Registry, Azure AI Services, and Microsoft Entra applications.
- Create (or identify) an **Entra security group** whose members should have `admin` access to Argo CD. The group name is looked up in [entra.tf](./entra.tf) and defaults to `CloudNative`; update the `display_name` there to match your group before deploying.

> [!TIP]
> The AzureRM Terraform provider will automatically register required resource providers during deployment. If your account lacks permission to register providers, register them manually with `az provider register --namespace <provider-name>` before running `terraform apply`.

> [!NOTE]
> Creating the Microsoft Entra application, service principal, and app role assignment requires sufficient directory permissions. If you cannot create Entra apps in your tenant, ask an administrator to provision them or adjust [entra.tf](./entra.tf) accordingly.

## Deploy

Log in to your Azure account and set the subscription you want to use. The AzureRM provider reads the subscription from your Azure CLI context, so no `ARM_SUBSCRIPTION_ID` export is needed for local CLI-authenticated runs.

```bash
az login
az account set -s <subscription-id>
```

Review the variables in [variables.tf](./variables.tf) before deploying. Key options:

- `location` - Azure region for the resources (default: `westus3`).
- `tags` - Tags applied to the resources (default: `environment = demo`, `project = msbuild26-ltg408`).

Initialize Terraform and deploy.

```bash
terraform init
terraform apply
```

Log into the AKS cluster.

```bash
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
```

## Verify

Confirm Argo CD is reachable and that Entra SSO works. Port-forward the Argo CD server, then log in with single sign-on (the server is configured for `localhost:8080`, matching the app registration's redirect URIs).

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
argocd login localhost:8080 --sso --insecure
argocd account get-user-info
```

`argocd account get-user-info` should return your signed-in identity and the groups used to grant the `admin` role, confirming the Entra integration end to end.

## Demo flow

With the infrastructure in place, the session runs three demos against the same container image:

1. **Deploy with AKS Desktop.** Register the cluster, use the deployment wizard to generate manifests from the `contoso-air` container image, and ship it to the `team-blue` namespace with Kubernetes best practices applied.
2. **Manage with AKS Desktop.** Scale the app, view metrics and logs, inspect networking, RBAC, and resource quotas, then edit the deployment to fix the port mapping, set up an HPA, and complete the chat integration using workload identity against Azure AI.
3. **Make it repeatable with the AKS extension for VS Code.** Generate manifests in the editor, commit them to source control, create an Argo CD `Application` pointing at the repo, and let Argo CD reconcile changes automatically as new image versions are pushed.

## Cleanup

```bash
terraform destroy
```

## Reference

- [Securing Argo CD with Microsoft Entra ID: A Step-by-Step Guide](https://blog.aks.azure.com/2026/04/22/argocd-extension-with-microsoft-entra)
- [AKS Desktop](https://aka.ms/aks/desktop)
- [AKS extension for Visual Studio Code](https://learn.microsoft.com/azure/aks/aks-extension-vs-code)
