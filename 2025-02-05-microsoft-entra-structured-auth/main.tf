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

resource "local_file" "kind_config" {
  filename = "kindconfig1.yaml"
  content = templatefile("kindconfig1.tmpl",
    {
      TENANT_ID = data.azuread_client_config.current.tenant_id
      CLIENT_ID = azuread_application.example.client_id
    }
  )
}

resource "local_file" "auth_config" {
  filename = "./structured-auth.yaml"
  content = templatefile("structured-auth.tmpl",
    {
      TENANT_ID = data.azuread_client_config.current.tenant_id
      CLIENT_ID  = azuread_application.example.client_id
    }
  )
}

resource "local_file" "azure_cluster_admin_rolebinding" {
  filename = "./azure-cluster-admin-rolebinding.yaml"
  content = templatefile("azure-cluster-admin-rolebinding.tmpl",
    {
      GROUP_ID = azuread_group.example.object_id
    }
  )
}