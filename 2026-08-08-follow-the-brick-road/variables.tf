variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westus3"
}

variable "dns_zone_name" {
  description = "The DNS zone name to be created for Argo CD ingress."
  type        = string
  default     = "paulyu.rocks"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    environment = "demo"
    project     = "azure-builtright"
  }
}
