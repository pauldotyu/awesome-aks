variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westus3"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    owner = "pauyu"
  }
}

variable "admin_username" {
  description = "The admin username for the Windows VM"
  type        = string
  default     = "adminuser"
}
