#!/bin/bash

cd ../../../aks-store-demo-manifests
git reset --hard build-ai
git push -f


cd ../aks-store-demo
git reset --hard build-ai
git push -f

gh release delete 2.0.0 -y
git tag -d 2.0.0
git push --delete origin 2.0.0

GH_USER=$(gh api user --jq .login) 
#gh auth login --scopes repo,workflow,write:packages
#gh auth token | docker login ghcr.io -u $GH_USER --password-stdin

docker build --platform=linux/amd64,linux/arm64 --build-arg APP_VERSION=1.0.0 --push -t ghcr.io/$GH_USER/aks-store-demo/ai-service:latest -t ghcr.io/$GH_USER/aks-store-demo/ai-service:1.0.0 ./src/ai-service