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

resource "local_file" "auth_config" {
  filename = "./structured-auth.yaml"
  content = templatefile("structured-auth.tmpl",
    {
      ISSUER_URL = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
      CLIENT_ID  = azuread_application.example.client_id
    }
  )
}

