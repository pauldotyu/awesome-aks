provider "okta" {
  org_name  = var.okta_org_name
  base_url  = var.okta_base_url
  api_token = var.okta_api_token
}

resource "okta_group" "example" {
  name        = "k8s-readers"
  description = "Users who can access k8s cluster as readers"
}

data "okta_user" "example" {
  search {
    name  = "profile.email"
    value = var.okta_user
  }
}

resource "okta_group_memberships" "example" {
  group_id = okta_group.example.id
  users = [
    data.okta_user.example.id
  ]
}

resource "okta_app_oauth" "example" {
  label                      = "k8s-oidc"
  type                       = "native"
  token_endpoint_auth_method = "none"

  grant_types = [
    "authorization_code"
  ]

  response_types = ["code"]

  redirect_uris = [
    "http://localhost:8000",
  ]

  post_logout_redirect_uris = [
    "http://localhost:8000",
  ]
}

resource "okta_app_group_assignments" "example" {
  app_id = okta_app_oauth.example.id
  group {
    id = okta_group.example.id
  }
}

resource "okta_auth_server" "example" {
  name      = "k8s-oidc"
  audiences = ["http:://localhost:8000"]
}

resource "okta_auth_server_claim" "example" {
  name                    = "groups"
  auth_server_id          = okta_auth_server.example.id
  always_include_in_token = true
  claim_type              = "IDENTITY"
  group_filter_type       = "STARTS_WITH"
  value                   = "k8s-"
  value_type              = "GROUPS"
}

resource "okta_auth_server_policy" "example" {
  name             = "k8s-policy"
  auth_server_id   = okta_auth_server.example.id
  description      = "Policy for allowed clients"
  priority         = 1
  client_whitelist = [okta_app_oauth.example.id]
}

resource "okta_auth_server_policy_rule" "example" {
  name           = "AuthCode + PKCE"
  auth_server_id = okta_auth_server.example.id
  policy_id      = okta_auth_server_policy.example.id
  priority       = 1

  grant_type_whitelist = [
    "authorization_code"
  ]

  scope_whitelist = ["*"]
  group_whitelist = ["EVERYONE"]
}
