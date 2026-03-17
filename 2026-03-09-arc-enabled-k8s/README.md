# Managing Kubernetes clusters everywhere

Work in progress...

## Notes

- The Terraform in this folder intentionally serializes `az connectedk8s connect` across the `staging`, `canary`, and `prod` kind contexts.
  - The reason is a limitation in the Azure CLI `connectedk8s` extension during pre-onboarding checks: concurrent connects reuse the same local cache path under `~/.azure/PreOnboardingChecksCharts/clusterdiagnosticchecks`, which causes untar collisions like `failed to untar ... already exists`.
  - KIND cluster creation can still happen in parallel, but Arc onboarding should run one cluster at a time.
- For the Argo CD extension settings, the dotted Helm keys under `configs.cm` and `configs.rbac.policy` must stay escaped. In CLI form that means keys like `configs.cm.oidc\.config`; in Terraform quoted strings that becomes `configs.cm.oidc\\.config`.
