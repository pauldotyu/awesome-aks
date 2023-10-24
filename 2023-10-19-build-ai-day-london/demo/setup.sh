#!/bin/bash

# Going up...
../

# Deploy the Azure resources
time terraform apply -var gh_user=$(gh api user --jq .login) -var gh_token=$(gh auth token) --auto-approve

# Get the ingress IP
echo "http://$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Get the AKS credentials
az aks get-credentials -n $(terraform output -raw aks_name) -g $(terraform output -raw rg_name)