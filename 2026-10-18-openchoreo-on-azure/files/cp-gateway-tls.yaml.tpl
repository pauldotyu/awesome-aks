# The control-plane serving certificate, issued by the selected Let's Encrypt
# ClusterIssuer via Azure DNS DNS-01.
#
# The DNS names cover the control plane today and pre-provision the data plane
# (*.apps.aks.rocks) and an optional observability plane
# (observer.obs.aks.rocks) on the same zone, so the same issuer path can be
# reused later without changing the certificate approach.
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cp-gateway-tls
  namespace: ${namespace}
spec:
  secretName: cp-gateway-tls
  issuerRef:
    group: cert-manager.io
    kind: ClusterIssuer
    name: ${issuer}
  dnsNames:
%{ for name in dns_names ~}
    - "${name}"
%{ endfor ~}
  privateKey:
    algorithm: RSA
    size: 2048
    rotationPolicy: Always
