#! /bin/bash

kind delete cluster
kubectl config delete-user azure-user
kubectl config delete-user okta-user
kubectl oidc-login clean
terraform destroy --auto-approve