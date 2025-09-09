variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "centralus"
}

variable "ai_location" {
  description = "The location/region where the Azure OpenAI service will be created."
  type        = string
  default     = "eastus2"
}

variable "pw_location" {
  description = "The location/region where the Playwright service will be created."
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    environment = "demo"
    project     = "aks-automatic-virtual-launch"
  }
}

variable "dns_zone_name" {
  description = "The name of the DNS zone to create."
  type        = string
  default     = "example.com"
}