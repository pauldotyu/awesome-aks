variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "switzerlandnorth"
}

variable "ai_location" {
  description = "The location/region where the Azure OpenAI service will be created."
  type        = string
  default     = "switzerlandnorth"
}

variable "lt_location" {
  description = "The location/region where the Load Test service will be created."
  type        = string
  default     = "westeurope"
}

variable "pw_location" {
  description = "The location/region where the Playwright service will be created."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    environment = "demo"
    project     = "msignite"
  }
}

variable "dns_zone_name" {
  description = "The name of the DNS zone to create."
  type        = string
  default     = "aks.rocks"
}

variable "alert_email" {
  description = "The email address to send alerts to."
  type        = string
  default     = "pauyu@microsoft.com"
}
