variable "deployment_locations" {
  type = list(object({
    offset   = number
    count    = number
    location = string
    vm_sku   = string
  }))
}