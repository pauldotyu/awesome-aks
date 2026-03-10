variable "location" {
  description = "The location/region where most of the resources will be created."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    environment = "demo"
    project     = "kubeconeu-2026"
  }
}