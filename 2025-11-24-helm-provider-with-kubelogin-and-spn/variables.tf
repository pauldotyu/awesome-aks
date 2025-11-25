variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westeurope"
}

variable "service_principal_tenant_id" {
  description = "The tenant ID of the service principal to be assigned the AKS Cluster Admin role."
  type        = string
}

variable "service_principal_object_id" {
  description = "The object ID of the service principal to be assigned the AKS Cluster Admin role."
  type        = string
}

variable "service_principal_client_id" {
  description = "The client ID of the service principal to be assigned the AKS Cluster Admin role."
  type        = string
}

variable "service_principal_client_secret" {
  description = "The client secret of the service principal to be assigned the AKS Cluster Admin role."
  type        = string
  sensitive   = true
}