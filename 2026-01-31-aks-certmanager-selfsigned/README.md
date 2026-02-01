# AKS with cert-manager and a self-signed TLS certificate

This Terraform sample follows Part 1 of the cert-manager tutorial: [Deploy cert-manager on Azure Kubernetes Service (AKS) and use Let's Encrypt to sign a certificate for an HTTPS website](https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/). It installs cert-manager and issues a self-signed TLS certificate for a demo HTTPS service.

Terraform creates:

- Resource group
- AKS cluster
- Azure DNS zone (used for naming the certificate and URL in this demo)

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

This provisions the AKS cluster and DNS zone and deploys cert-manager into the cluster.

## Deploy cert-manager resources

Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group $(terraform output -raw rg_name) --name $(terraform output -raw aks_name)
```

Create a cert-manager `ClusterIssuer` named `selfsigned`. A `ClusterIssuer` is a cluster-scoped certificate authority configuration.

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned
spec:
  selfSigned: {}
EOF
```

Create a cert-manager `Certificate` named `www`. This requests a self-signed certificate for the `www` subdomain of the DNS zone name created by Terraform. cert-manager generates a keypair and stores it in a Secret named `www-tls`. The `rotationPolicy: Always` ensures a new private key is generated on renewal. The DNS name is built from the Terraform DNS zone output to match the tutorial’s `www.<domain>` pattern.

```bash
URL=www.$(terraform output -raw dns_zone_name)

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: www
spec:
  secretName: www-tls
  privateKey:
    rotationPolicy: Always
  commonName: $URL
  dnsNames:
    - $URL
  usages:
    - digital signature
    - key encipherment
    - server auth
  issuerRef:
    name: selfsigned
    kind: ClusterIssuer
EOF
```

Wait a few moments for cert-manager to issue the certificate. Check status with:

```bash
kubectl describe certificate www
```

## Deploy sample HTTPS workload

Deploy a sample HTTPS workload that uses the issued certificate. The deployment runs an HTTPS app on port 8443 and mounts the `www-tls` Secret. A `LoadBalancer` Service exposes the app via a public Azure Load Balancer.

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

With the Load Balancer ready, test the HTTPS service. Since the domain isn’t publicly registered, add a local [/etc/hosts](/etc/hosts) entry that maps the Load Balancer’s public IP to the Terraform DNS name. This allows you to reach the service using the expected hostname without setting up public DNS.

```bash
PUBLIC_IP=$(kubectl get svc helloweb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat <<EOF | sudo tee -a /etc/hosts
${PUBLIC_IP} ${URL}
EOF
```

Send an HTTPS request to the Load Balancer’s DNS name. The `--insecure` flag is required because the certificate is self-signed. You should see a successful response from the sample HTTPS service, which confirms the certificate was issued and mounted.

```bash
curl --insecure -v https://$URL
```

## Cleanup

When you are done testing, you can delete the Azure resources (this also removes the AKS cluster and all Kubernetes resources) with:

```bash
terraform destroy -auto-approve
```

Remove the [/etc/hosts](/etc/hosts) entry when done:

```bash
sudo sed -i.bak "/${PUBLIC_IP} ${URL}/d" /etc/hosts
```
