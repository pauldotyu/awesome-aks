variable "location" {
  type        = string
  default     = "eastus"
  description = "value of location"
}

variable "kaito_gpu_provisioner_version" {
  type        = string
  default     = "0.2.0"
  description = "kaito gpu provisioner version"
}

variable "kaito_workspace_version" {
  type        = string
  default     = "0.3.2"
  description = "kaito workspace version"
}

variable "registry_repository_name" {
  type        = string
  default     = "fine-tuned-adapters/products"
  description = "container registry repository name"
}
