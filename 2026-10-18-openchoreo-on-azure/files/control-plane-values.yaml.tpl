# OpenChoreo control-plane values for this deployment.
#
# Rendered by templatefile from local.openchoreo_values. Every key path below is
# validated against the pinned v1.3.1 chart's values.schema.json. Notable:
#   * security.oidc.* feeds the Backstage deployment's OPENCHOREO_AUTH_* env
#   * security.jwt.audience becomes the API's JWT audiences list
#   * authorization.bootstrap.mappings use the chart's NESTED shape
#     { entitlement: {claim,value}, roleMappings: [ {roleRef:{kind,name}} ], effect }
#     (NOT a flat claim/value/role as a generic example might suggest)
#   * backend-secret/service-client-secret are read from the backstage-secrets
#     Kubernetes Secret (materialized from Azure Key Vault by ESO), never inlined
#
openchoreoApi:
  config:
    server:
      publicUrl: "https://${api_hostname}"
    security:
      subjects:
        user:
          display_name: User
          priority: 1
          mechanisms:
            jwt:
              entitlement:
                claim: groups
                display_name: Entra Group Object ID
        service_account:
          display_name: Service Account
          priority: 2
          mechanisms:
            jwt:
              # Default readable_id_claim is "client_id"; override to "azp" so no
              # Entra v2 service-token path relies on client_id. Entitlement
              # matches on azp, which for a client-credentials token equals the
              # issuing service application's client id.
              readable_id_claim: azp
              entitlement:
                claim: azp
                display_name: Entra Application Client ID
      authorization:
        bootstrap:
          mappings:
            - name: platform-engineer-${platform_engineer_group_slug}
              kind: ClusterAuthzRoleBinding
              system: true
              entitlement:
                claim: groups
                value: "${platform_engineer_group_object_id}"
              effect: allow
              roleMappings:
                - roleRef:
                    kind: ClusterAuthzRole
                    name: platform-engineer
            - name: backstage-catalog-reader
              kind: ClusterAuthzRoleBinding
              system: true
              entitlement:
                claim: azp
                value: "${openchoreo_backstage_service_client_id}"
              effect: allow
              roleMappings:
                - roleRef:
                    kind: ClusterAuthzRole
                    name: backstage-catalog-reader
  http:
    hostnames:
      - "${api_hostname}"

backstage:
  secretName: "backstage-secrets"
  baseUrl: "https://${console_hostname}"
  http:
    hostnames:
      - "${console_hostname}"
  auth:
    clientId: "${openchoreo_backstage_client_id}"
    # NOTE: accepted by the v1.3.1 schema but not consumed by any v1.3.1
    # template. The effective redirect is derived from backstage.baseUrl at
    # runtime as <baseUrl>/api/auth/openchoreo-auth/handler/frame. Kept here
    # for clarity / future-proofing.
    redirectUrls:
      - "${console_auth_redirect_uri}"
    oidcScope: "openid profile email offline_access ${openchoreo_api_app_id_uri}/access_as_user"
    serviceClientId: "${openchoreo_backstage_service_client_id}"
    serviceClientSecretKey: "service-client-secret"
    scope: "${openchoreo_api_app_id_uri}/.default"

security:
  oidc:
    issuer: "${oidc_issuer}"
    wellKnownEndpoint: "${oidc_well_known}"
    jwksUrl: "${oidc_jwks_url}"
    authorizationUrl: "${oidc_authorize}"
    tokenUrl: "${oidc_token}"
  jwt:
    audience: "${openchoreo_api_client_id}"

gateway:
  tls:
    enabled: true
    hostname: "*.aks.rocks"
    certificateRefs:
      - name: cp-gateway-tls
