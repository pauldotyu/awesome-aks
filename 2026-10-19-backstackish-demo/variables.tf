variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westus3"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    owner = "paul"
  }
}

variable "admin_email" {
  description = "The admin email to be used for cert-manager."
  type        = string
}

variable "dns_zone_name" {
  description = "The DNS zone name to be created for Argo CD ingress."
  type        = string
}

variable "entra_group_name" {
  description = "The name of the Entra ID group to be used for assigning access to Argo CD."
  type        = string
  default     = "CloudNative"
}

variable "control_kubernetes_version" {
  description = "The Kubernetes version to use for the control plane."
  type        = string
  default     = "1.37"
}

variable "control_vm_size" {
  description = "The VM size to use for the control plane nodes."
  type        = string
  default     = "Standard_D4s_v6"
}

variable "crossplane_provider_opentofu_version" {
  description = "The version of the Crossplane provider for OpenTofu."
  type        = string
  default     = "v1.1.10"
}

variable "crossplane_function_go_templating_version" {
  description = "The version of the Crossplane Go Templating function."
  type        = string
  default     = "v0.13.1"
}

variable "crossplane_function_auto_ready_version" {
  description = "The version of the Crossplane Auto Ready function."
  type        = string
  default     = "v0.7.1"
}

variable "backstage_github_token" {
  description = "The GitHub Personal Access Token (PAT) for Backstage."
  type        = string
  sensitive   = true
}

variable "backstage_user_object_ids" {
  description = "A list of user object IDs to be added to the Backstage users group."
  type        = list(string)
  default     = []
}

variable "argocd_user_object_ids" {
  description = "A list of user object IDs to be added to the Argo CD users group."
  type        = list(string)
  default     = []
}

variable "external_secrets_version" {
  description = "External Secrets Operator OCI chart version."
  type        = string
  default     = "2.0.1"
}