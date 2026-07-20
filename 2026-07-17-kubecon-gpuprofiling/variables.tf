variable "location" {
  description = "The region where most of the Azure resources will be deployed."
  type        = string
  default     = "switzerlandnorth"
}

variable "anyscale_cloud_location" {
  description = "The region where the Anyscale cloud resource will be deployed. Must be a region that Anyscale supports. See https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions for more details."
  type        = string
  default     = "eastus"
  validation {
    condition     = contains(["westcentralus", "eastus", "eastus2", "westus2", "westus3", "southcentralus"], var.anyscale_cloud_location)
    error_message = "The location must be one of the following: westcentralus, eastus, eastus2, westus2, westus3, southcentralus."
  }
}

variable "system_node_pool_vm_count" {
  description = "The number of nodes in the system node pool in the AKS cluster. Must be a positive integer."
  type        = number
  default     = 3
  validation {
    condition     = var.system_node_pool_vm_count > 0
    error_message = "The system_node_pool_vm_count must be a positive integer."
  }
}

variable "nvidia_sku_name" {
  description = "The VM size for the gpu node pool in the AKS cluster. Must be a size that is supported in the chosen location. See https://learn.microsoft.com/azure/anyscale-on-azure/supported-regions for more details."
  type        = string
  default     = "Standard_NV72ads_A10_v5"
}
