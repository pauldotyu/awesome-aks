# BACK-ish Stack Demo

## Provision Azure infrastructure

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
az aks get-credentials -n $(terraform output -raw aks_name -o tsv) -g $(terraform output -raw rg_name -o tsv)
```

## Configure cert-manager

Deploy a cert-manager ClusterIssuer resource

```sh
kubectl apply -f kubernetes/cert-manager.yaml
```

## Configure Backstage

Create the secret store and external secrets for Backstage

```sh
kubectl apply -f kubernetes/external-secrets.yaml
```

> Source: [https://external-secrets.io/latest/provider/azure-key-vault/](https://external-secrets.io/latest/provider/azure-key-vault/)

Install Backstage

```sh
helm upgrade --install backstage oci://ghcr.io/pauldotyu/charts/backstage \
  --version 0.1.0-sha-afd05b4 -n backstage -f kubernetes/backstage-values.yaml
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

## Configure Argo CD

Deploy Argo CD certificate request and gateway

```sh
kubectl apply -f kubernetes/argo-cd.yaml
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

## Configure Crossplane

Deploy OpenTofu provider for Crossplane

```sh
kubectl apply -f kubernetes/crossplane.yaml
```

Make sure the provider is installed and healthy

```sh
kubectl get providers
```

Configure the OpenTofu provider

```sh
kubectl apply -f kubernetes/opentofu-state.yaml
```
