# ClusterSecretStore + ExternalSecret: project the four Azure Key Vault secrets
# into the `backstage-secrets` Kubernetes Secret in the OpenChoreo control-plane
# namespace.
#
# ESO authenticates to Key Vault with the mounted Workload Identity on the ESO
# controller (its service account is annotated with the UAMI client id).
---
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: azure-keyvault
spec:
  refreshInterval: 60m
  provider:
    azureKeyVault:
      vaultUrl: ${vault_url}
      authType: WorkloadIdentity
      tenantId: ${tenant_id}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: backstage-secrets
  namespace: ${namespace}
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: azure-keyvault
  target:
    name: backstage-secrets
    creationPolicy: Owner
    template:
      type: Opaque
  data:
    - secretKey: backend-secret
      remoteRef:
        key: ${kv_backend_secret}
    - secretKey: client-secret
      remoteRef:
        key: ${kv_client_secret}
    - secretKey: service-client-secret
      remoteRef:
        key: ${kv_service_client_secret}
    - secretKey: jenkins-api-key
      remoteRef:
        key: ${kv_jenkins_api_key}
