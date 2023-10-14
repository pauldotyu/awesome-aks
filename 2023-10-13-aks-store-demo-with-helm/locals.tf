resource "random_integer" "example" {
  min = 10
  max = 99
}

locals {
  name     = "petstore${random_integer.example.result}"
  location = var.location
}