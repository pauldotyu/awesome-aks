# Network Observability Addon for AKS

Before running the `terraform apply` command, be sure you have Azure CLI installed and logged in using `az login`. It is also important to ensure you have the `NetworkObservabilityPreview` feature enabled in your subscription.

The following command will enable the feature in your subscription:

```bash
az feature register --namespace "Microsoft.ContainerService" --name "NetworkObservabilityPreview"
```