terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }

    okta = {
      source  = "okta/okta"
      version = "~> 4.14.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.2"
    }
  }
}
