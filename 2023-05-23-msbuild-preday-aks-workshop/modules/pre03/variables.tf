variable "user_count" {
  type = number
}

variable "user_offset" {
  type = number
}

variable "user_password" {
  type      = string
  sensitive = true
}

variable "primary_domain" {
  type = string
}

variable "location" {
  type = string
}

variable "shared_resource_group_id" {
  type = string
}

variable "shared_log_analytics_workspace_id" {
  type = string
}

variable "managed_grafana_resource_id" {
  type = string
}

variable "unique_string" {
  type        = string
  description = "A unique string to append to resource names to ensure they are unique across all of Azure."
}

variable "vm_sku" {
  type        = string
  description = "The SKU of the virtual machine."
}