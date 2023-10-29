apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: store-front-gateway
  namespace: ${K8S_NAMESPACE}
  annotations:
    alb.networking.azure.io/alb-name: aks-store-demo-alb
    alb.networking.azure.io/alb-namespace: azure-alb-system
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http-listener
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: store-admin-gateway
  namespace: ${K8S_NAMESPACE}
  annotations:
    alb.networking.azure.io/alb-name: aks-store-demo-alb
    alb.networking.azure.io/alb-namespace: azure-alb-system
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http-listener
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same