apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: aks-store-demo-alb
  namespace: azure-alb-system
spec:
  associations:
  - ${ALB_SUBNET_ID}