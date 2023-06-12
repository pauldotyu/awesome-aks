apiVersion: azconfig.io/v1beta1
kind: AzureAppConfigurationProvider
metadata:
  name: my-appconfig-provider
spec:
  endpoint: ${APP_CONFIG_ENDPOINT}
  target:
    configMapName: my-configmap
  keyValues: 
    selectors:
      - keyFilter: settings.*
      - keyFilter: secrets.*  
    keyVaults:
      target:
        secretName: my-secrets
      auth:
        managedIdentityClientId: ${NODE_VMSS_MANAGED_CLIENT_ID}