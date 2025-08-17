variable "location" {
  description = "The Azure region where the resources will be created."
  type        = string
  default     = "eastus2"
}

variable "node_pool_count" {
  description = "The number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "node_pool_vm_size" {
  description = "The size of the virtual machines in the default node pool."
  type        = string
  default     = "Standard_D2s_v5"
}