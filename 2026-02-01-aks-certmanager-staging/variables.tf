variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westus3"
}

variable "dns_zone_name" {
  description = "The DNS name to be used for the DNS zone."
  type        = string
  default     = "paulyu.rocks"
}