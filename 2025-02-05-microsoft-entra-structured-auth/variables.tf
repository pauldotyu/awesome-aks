variable "okta_base_url" {
  type        = string
  description = "okta.com"
}

variable "okta_org_name" {
  type        = string
  description = "your okta organization name example: okta-dev-xxxxx"
}

variable "okta_api_token" {
  type        = string
  description = "your okta api token which can be set from: https://dev-xxxxx-admin.okta.com/admin/access/api/tokens"
  sensitive   = true
}

variable "okta_user" {
  type        = string
  description = "your okta user email"
}
