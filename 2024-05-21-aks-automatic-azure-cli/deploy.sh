#!/bin/sh

az group create -n myResourceGroup -l eastus

MONITOR_ID=$(az monitor account create -n myMetrics$RANDOM -g myResourceGroup --query id -o tsv)
LOGS_ID=$(az monitor log-analytics workspace create -n myLogs$RANDOM -g myResourceGroup --query id -o tsv)
GRAFANA_ID=$(az grafana create -n myGrafana$RANDOM -g myResourceGroup --query id -o tsv)

az aks create -n myAKSCluster -g myResourceGroup \
  --sku automatic \
  --azure-monitor-workspace-resource-id $MONITOR_ID \
  --workspace-resource-id $LOGS_ID \
  --grafana-resource-id $GRAFANA_ID