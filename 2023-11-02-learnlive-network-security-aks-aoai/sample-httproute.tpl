apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: store-front-route
  namespace: ${K8S_NAMESPACE}
spec:
  parentRefs:
  - name: store-front-gateway
  hostnames:
  - "${STORE_FRONT_FQDN}"
  rules:
  - backendRefs:
    - name: store-front
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: store-admin-route
  namespace: ${K8S_NAMESPACE}
spec:
  parentRefs:
  - name: store-admin-gateway
  hostnames:
  - "${STORE_ADMIN_FQDN}"
  rules:
  - backendRefs:
    - name: store-admin
      port: 80