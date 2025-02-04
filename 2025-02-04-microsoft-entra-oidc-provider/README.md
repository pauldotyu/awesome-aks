# Microsoft Entra as Kubernetes OIDC Provider

This demo walks you through the steps to configure Microsoft Entra ID as an OIDC provider for Kubernetes. The demo uses Terraform to create an application registration in Microsoft Entra ID, KIND to create a Kubernetes cluster, and kubectl to configure the OIDC user.

## Prerequisites

- [Microsoft Entra](https://learn.microsoft.com/entra/fundamentals/what-is-entra) account with permissions to create an application registration, group, and assign users to the group.
- [Terraform CLI](https://developer.hashicorp.com/terraform/install?product_intent=terraform)
- [KIND (Kubernetes in Docker)](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [krew](https://krew.sigs.k8s.io/docs/user-guide/quickstart/) to install [kubelogin also known as oidc-login](https://github.com/int128/kubelogin?tab=readme-ov-file#setup)


## Create an application registration in Microsoft Entra ID

Run the following command to initialize the Terraform providers.

```bash
terraform init
```

Create Microsoft Entra resources using Terraform.

```bash
terraform apply
```

## Create KIND cluster

Create a KIND cluster using a custom configuration file to enable OIDC authentication.

```bash
kind create cluster --config myconfig.yaml
```

## Create a RoleBinding

Create a ClusterRoleBinding to bind the `cluster-admin` role to the new group that created was created Microsoft Entra via Terraform.

```bash
kubectl apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: oidc-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: Group
  name: $(terraform output -raw group_id)
EOF
```

## Create OIDC user

Create a new user in the kubeconfig file using the `oidc-login` plugin. This will force the user to authenticate using Microsoft Entra.

```bash
kubectl config set-credentials oidc-user \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-interactive-mode=Never \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg="--oidc-issuer-url=https://login.microsoftonline.com/$(terraform output -raw tenant_id)/v2.0" \
  --exec-arg="--oidc-client-id=$(terraform output -raw client_id)"
```

## Set the context

Set the current context to use the OIDC user.

```bash
kubectl config set-context --current --user=oidc-user
```

## Test the configuration

Run the following command to test the configuration. This command should return the nodes in the Kubernetes cluster after authenticating with Microsoft Entra.

```bash
kubectl get nodes
```

## Clean up

When you are done testing, run the following commands to clean up the resources.

```bash
kind delete cluster
kubectl config delete-user oidc
kubectl oidc-login clean
terraform destroy
```
