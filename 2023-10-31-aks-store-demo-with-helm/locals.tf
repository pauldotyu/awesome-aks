resource "random_integer" "example" {
  min = 10
  max = 99
}

locals {
  name     = "pets${random_integer.example.result}"
  location = var.location
}