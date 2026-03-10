# AKS Desktop at KubeCon EU 2026

Work in progress...

```sh
read -r RG_NAME AKS_NAME <<< "$(
  terraform output -json | jq -r '[
    .rg_name.value,
    .aks_name.value
  ] | @tsv'
)"
```

```sh
az aks get-credentials \
--resource-group $RG_NAME \
--name $AKS_NAME
```
