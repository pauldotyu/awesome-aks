# Microsoft Entra as Kubernetes OIDC Provider with Structured Authentication

This demo walks you through the steps to configure Microsoft Entra ID as an OIDC provider for Kubernetes using a structured authentication configuration file. The demo uses Terraform to create an application registration in Microsoft Entra ID, KIND to create a Kubernetes cluster, and kubectl to configure the OIDC user.

## Prerequisites

- [Microsoft Entra](https://learn.microsoft.com/entra/fundamentals/what-is-entra) account with permissions to create an application registration, group, and assign users to the group.
- [Okta Developer](https://developer.okta.com/) account with permissions to create an application registration, group, and assign users to the group.
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
kind create cluster --config kindconfig1.yaml
```

Create a pod to test the configuration.

```bash
kubectl run mybusybox --image=busybox --restart=Never --command -- sleep 3600
```

## Create a RoleBinding

Create a ClusterRoleBinding to bind the `cluster-admin` role to the new group that created was created Microsoft Entra via Terraform.

```bash
kubectl apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: azure-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: Group
  name: $(terraform output -raw microsoft_group_id)
EOF
```

## Create Azure user

Create a new Azure user in the kubeconfig file using the `oidc-login` plugin. This will force the user to authenticate using Microsoft Entra.

```bash
kubectl config set-credentials azure-user \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-interactive-mode=Never \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=$(terraform output -raw microsoft_issuer_url) \
  --exec-arg=--oidc-client-id=$(terraform output -raw microsoft_client_id) \
  --exec-arg=--oidc-extra-scope="email offline_access profile openid"
```

## Test the configuration

Run the following commands to test the configuration. These commands should return the pods and nodes in the Kubernetes cluster after authenticating with Microsoft Entra.

```bash
kubectl get pods --user=azure-user
kubectl get nodes --user=azure-user
```

You should be presented with a login prompt to authenticate with Microsoft Entra. After successful authentication, you should see the nodes in the Kubernetes cluster.

## Add another JWT provider

Run the following command to append another JWT provider to the structured authentication configuration file.

```bash
cat <<EOF >> structured-auth.yaml
- issuer:
    url: $(terraform output -raw okta_issuer_url)
    audiences:
    - $(terraform output -raw okta_client_id)
  claimMappings:
    username:
      claim: "email"
      prefix: ""
    groups:
      claim: "groups"
      prefix: ""
EOF
```

## Create a Role and RoleBinding for the new user and group

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: po-svc-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "watch", "list"]
EOF

kubectl apply -f - <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: okta-po-svc-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: po-svc-reader
subjects:
- kind: Group
  name: $(terraform output -raw okta_group_name)
EOF
```

## Create a new Okta user

```bash
kubectl config set-credentials okta-user \
--exec-api-version=client.authentication.k8s.io/v1beta1 \
--exec-command=kubectl \
--exec-arg=oidc-login \
--exec-arg=get-token \
--exec-arg=--oidc-issuer-url=$(terraform output -raw okta_issuer_url) \
--exec-arg=--oidc-client-id=$(terraform output -raw okta_client_id) \
--exec-arg=--oidc-extra-scope="email offline_access profile openid"
```

## Test the new configuration

Run the following command to test the new configuration. This command should return the pods in the Kubernetes cluster after authenticating with Okta.

```bash
kubectl get pods --user=okta-user
```

Now run the following command. This command should return a forbidden error because the user does not have permission to list the nodes in the Kubernetes cluster.

```bash
kubectl get nodes --user=okta-user
```

## CEL expression for claim validation

Open the structured-auth.yaml file and add this to the Microsoft issuer configuration.

```yaml
claimValidationRules:
  - expression: "claims.name.startsWith('Bob')"
    message: only people named Bob are allowed
```

Clear the oidc-login cache.

```bash
kubectl oidc-login clean
```

Run the following command to test the claim validation.

```bash
kubectl get pods --user=azure-user
```

## Clean up

When you are done testing, run the following commands to clean up the resources.

```bash
kind delete cluster
kubectl config delete-user azure-user
kubectl config delete-user okta-user
kubectl oidc-login clean
terraform destroy
```

## Troubleshooting

The KIND cluster does not start because the OIDC configuration is incorrect. Check the logs for the KIND cluster to identify the issue.

```bash
docker logs -f kind-control-plane
```

Check to ensure the authentication configuration file was mounted correctly.

```bash
docker exec -it kind-control-plane cat /etc/kubernetes/structured-auth.yaml
```

Check kube-apiserver logs for any errors related to OIDC authentication.

```bash
docker exec -it kind-control-plane sh -c "cat /var/log/containers/kube-apiserver-kind-control-plane_kube-system_kube-apiserver-*.log"
```
