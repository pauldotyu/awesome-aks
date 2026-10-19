# Two Let's Encrypt ClusterIssuers (Azure DNS DNS-01 + Workload Identity).
# Rendered by templatefile; applied with kubectl.
#
# Both issuers are always created. Only the one selected by
# var.letsencrypt_environment backs the cp-gateway-tls certificate, so moving
# from staging to production is a one-variable change.
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-azure-dns-staging
  labels:
    app.kubernetes.io/managed-by: Helm
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
%{ if email != "" ~}
    email: ${email}
%{ endif ~}
    privateKeySecretRef:
      name: letsencrypt-azure-dns-staging
    solvers:
      - dns01:
          azureDNS:
            subscriptionID: ${subscription_id}
            resourceGroupName: ${resource_group_name}
            hostedZoneName: ${hosted_zone_name}
            environment: AzurePublicCloud
            managedIdentity:
              clientID: ${managed_identity_client_id}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-azure-dns-production
  labels:
    app.kubernetes.io/managed-by: Helm
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
%{ if email != "" ~}
    email: ${email}
%{ endif ~}
    privateKeySecretRef:
      name: letsencrypt-azure-dns-production
    solvers:
      - dns01:
          azureDNS:
            subscriptionID: ${subscription_id}
            resourceGroupName: ${resource_group_name}
            hostedZoneName: ${hosted_zone_name}
            environment: AzurePublicCloud
            managedIdentity:
              clientID: ${managed_identity_client_id}
