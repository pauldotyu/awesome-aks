# AKS with cert-manager and Let's Encrypt

This Terraform sample follows Part 2 of the cert-manager tutorial: [Deploy cert-manager on Azure Kubernetes Service (AKS) and use Let's Encrypt to sign a certificate for an HTTPS website](https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/). It installs cert-manager and issues a Let's Encrypt **staging** TLS certificate for a demo HTTPS service via DNS-01 with Azure DNS (safe for testing).

> [!important]
> This assumes you have a public domain registered and can update its nameservers to use the Azure DNS nameservers.

Terraform creates:

- Resource group
- AKS cluster
- Azure DNS zone and a CNAME record for the demo hostname

## Prerequisites

Before you begin, ensure you have met the following requirements:

- Azure CLI authenticated to a subscription
- Terraform installed
- kubectl installed
- Helm installed

## Provision Azure resources

Initialize Terraform and provision the Azure resources:

```bash
terraform init
terraform apply -auto-approve
```

This provisions the AKS cluster and DNS zone, creates a CNAME record that maps the demo hostname to the Azure Load Balancer DNS label, and deploys cert-manager into the cluster with Azure Workload Identity.

Read the Terraform outputs for use in the next steps, then delegate your DNS zone at your registrar using the nameservers shown:

```bash
read -r RG_NAME AKS_NAME DNS_ZONE_NAME DNS_ZONE_SUBDOMAIN LB_DNS_LABEL CLIENT_ID DNS_ZONE_NAMESERVERS <<< "$(terraform output -json | jq -r '[.rg_name.value,.aks_name.value,.dns_zone_name.value,.dns_zone_subdomain.value,.lb_dns_label.value,.mi_client_id.value,(.dns_zone_nameservers.value|join(","))] | @tsv')"

echo "Delegate your DNS zone to these nameservers (comma-separated): $DNS_ZONE_NAMESERVERS"
```

## Deploy cert-manager resources

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME
```

Create a cert-manager `ClusterIssuer` named `letsencrypt-staging`. This uses Azure DNS for DNS-01 validation with the user-assigned managed identity created by Terraform.

```bash
read -r EMAIL SUBSCRIPTION_ID <<< "$(az account show --query '{email:user.name, subscriptionId:id}' -o tsv)"

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $EMAIL
    profile: tlsserver
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        azureDNS:
          resourceGroupName: $RG_NAME
          subscriptionID: $SUBSCRIPTION_ID
          hostedZoneName: $DNS_ZONE_NAME
          environment: AzurePublicCloud
          managedIdentity:
            clientID: $CLIENT_ID
EOF
```

Create a cert-manager `Certificate` named `www`. This requests a Let's Encrypt **staging** certificate for the `www` subdomain. The keypair is stored in the `www-tls` Secret and `rotationPolicy: Always` forces a new private key on renewal. The DNS name is built from the Terraform outputs to match `www.<domain>`.

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www
spec:
  secretName: www-tls
  privateKey:
    rotationPolicy: Always
  commonName: $DNS_ZONE_SUBDOMAIN.$DNS_ZONE_NAME
  dnsNames:
    - $DNS_ZONE_SUBDOMAIN.$DNS_ZONE_NAME
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
EOF
```

Wait a few moments for cert-manager to issue the certificate. Check status with:

```bash
kubectl describe certificate www
```

## Deploy sample HTTPS workload

Deploy a sample HTTPS workload that uses the issued certificate. The deployment runs an HTTPS app on port 8443 and mounts the `www-tls` Secret. A `LoadBalancer` Service exposes the app; the DNS label annotation matches the Terraform CNAME.

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloweb
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
      tier: web
  template:
    metadata:
      labels:
        app: hello
        tier: web
    spec:
      containers:
        - name: hello-app
          image: us-docker.pkg.dev/google-samples/containers/gke/hello-app-tls:1.0
          imagePullPolicy: Always
          ports:
            - containerPort: 8443
          volumeMounts:
            - name: tls
              mountPath: /etc/tls
              readOnly: true
          env:
            - name: TLS_CERT
              value: /etc/tls/tls.crt
            - name: TLS_KEY
              value: /etc/tls/tls.key
      volumes:
        - name: tls
          secret:
            secretName: www-tls
---
apiVersion: v1
kind: Service
metadata:
  name: helloweb
  annotations:
    service.beta.kubernetes.io/azure-dns-label-name: $LB_DNS_LABEL
spec:
  ports:
    - port: 443
      protocol: TCP
      targetPort: 8443
  selector:
    app: hello
    tier: web
  type: LoadBalancer
EOF
```

Wait for the Load Balancer to be provisioned and obtain a public IP address:

```bash
kubectl get svc helloweb --watch
```

Once the `EXTERNAL-IP` field shows an IP address (not `<pending>`), press `Ctrl+C` to exit the watch.

## Test the HTTPS service

With the Load Balancer ready, test the HTTPS service.

> [!important]
> This assumes you have delegated the DNS zone created by Terraform to Azure DNS. Nameserver delegation can take time to propagate.

Send an HTTPS request to the DNS name. You should see a successful response from the sample HTTPS service, confirming the certificate was issued and mounted.

```bash
curl -vk https://$DNS_ZONE_SUBDOMAIN.$DNS_ZONE_NAME
```

The `-k` flag allows curl to proceed with the request even though the Let's Encrypt staging certificate is not trusted by your system. This is expected for staging certificates.

## Migrate to production

When you are satisfied with testing, you can migrate to a production Let's Encrypt certificate by creating a new `ClusterIssuer` and `Certificate` that use the production ACME server: `https://acme-v02.api.letsencrypt.org/directory`.

Create a cert-manager `ClusterIssuer` named `letsencrypt-production`:

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    profile: tlsserver
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        azureDNS:
          resourceGroupName: $RG_NAME
          subscriptionID: $SUBSCRIPTION_ID
          hostedZoneName: $DNS_ZONE_NAME
          environment: AzurePublicCloud
          managedIdentity:
            clientID: $CLIENT_ID
EOF
```

Recreate the cert-manager `Certificate` named `www`, this time referencing the `letsencrypt-production` issuer:

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www
spec:
  secretName: www-tls
  privateKey:
    rotationPolicy: Always
  commonName: $DNS_ZONE_SUBDOMAIN.$DNS_ZONE_NAME
  dnsNames:
    - $DNS_ZONE_SUBDOMAIN.$DNS_ZONE_NAME
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
EOF
```

Redeploy the sample HTTPS workload to mount the new production certificate:

```bash
kubectl rollout restart deployment helloweb
```

Test the HTTPS service again with curl:

```bash
curl -v https://$DNS_ZONE_SUBDOMAIN.$DNS_ZONE_NAME
```

Notice that this time, without the `-k` flag, curl should successfully verify the certificate chain up to Let's Encrypt's root CA.

## Cleanup

When you are done testing, you can delete the Azure resources (this also removes the AKS cluster and all Kubernetes resources) with:

```bash
terraform destroy -auto-approve
```
