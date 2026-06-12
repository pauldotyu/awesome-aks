variable "location" {
  description = "The Azure region where the resources will be deployed. Must be a region that supports Anyscale on Azure. See https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions for more details."
  type        = string
  default     = "westus3"
  validation {
    condition     = contains(["westcentralus", "eastus", "eastus2", "westus2", "westus3", "southcentralus"], var.location)
    error_message = "The location must be one of the following: westcentralus, eastus, eastus2, westus2, westus3, southcentralus."
  }
}

variable "system_node_pool_vm_count_min" {
  description = "The minimum number of nodes in the system node pool in the AKS cluster. Must be a positive integer."
  type        = number
  default     = 3
  validation {
    condition     = var.system_node_pool_vm_count_min > 0
    error_message = "The system_node_pool_vm_count_min must be a positive integer."
  }
}

variable "system_node_pool_vm_count_max" {
  description = "The maximum number of nodes in the system node pool in the AKS cluster. Must be a positive integer."
  type        = number
  default     = 9
  validation {
    condition     = var.system_node_pool_vm_count_max > var.system_node_pool_vm_count_min && var.system_node_pool_vm_count_max <= 100
    error_message = "The system_node_pool_vm_count_max must be a positive integer greater than system_node_pool_vm_count_min and less than or equal to 100."
  }
}

variable "system_node_pool_vm_size" {
  description = "The VM size for the system node pool in the AKS cluster. Must be a size that is supported in the chosen location. See https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions for more details."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "gpu_node_pool_vm_size" {
  description = "The VM size for the gpu node pool in the AKS cluster. Must be a size that is supported in the chosen location. See https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions for more details."
  type        = string
  default     = "Standard_NC40ads_H100_v5"
}

variable "gpu_node_pool_max_vm_count" {
  description = "The maximum number of nodes in the gpu node pool in the AKS cluster. Must be a positive integer."
  type        = number
  default     = 2
  validation {
    condition     = var.gpu_node_pool_max_vm_count > 0
    error_message = "The gpu_node_pool_max_vm_count must be a positive integer."
  }
}

variable "gpu_node_pool_min_vm_count" {
  description = "The minimum number of nodes in the gpu node pool in the AKS cluster. Must be a non-negative integer."
  type        = number
  default     = 0
}