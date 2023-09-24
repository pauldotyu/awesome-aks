resource "random_integer" "example" {
  min = 10
  max = 99
}

locals {
  name     = "gitops${random_integer.example.result}"
  location = var.location
}