variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westus3"
}

variable "admin_group_name" {
  description = "The name of the Azure AD group to create for admin access."
  type        = string
  default     = "CloudNative"
}

variable "vm_username" {
  description = "The admin username for the VM that will be created."
  type        = string
  default     = "paul"
}

variable "virtual_machines" {
  type = list(object({
    name = string
    size = string
  }))
  default = [
    {
      name = "kind"
      size = "Standard_B2ms"
    },
    {
      name = "flex"
      size = "Standard_B2ms"
    }
  ]
  description = "List of virtual machines to create with their name and size."
}

variable "environments" {
  description = "List of environments to create resources for."
  type        = list(string)
  default     = ["staging", "canary", "prod"]
}