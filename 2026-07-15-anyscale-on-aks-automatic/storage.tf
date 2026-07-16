resource "azurerm_storage_account" "example" {
  name                            = "${local.random_name}${random_string.example.result}"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  is_hns_enabled                  = true
  default_to_oauth_authentication = true
  shared_access_key_enabled       = true

  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["DELETE", "GET", "HEAD", "POST", "PUT"]
      allowed_origins    = ["https://*.anyscale.com"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = {
    "anyscale-cloud" = local.random_name
  }
}

resource "azurerm_storage_container" "example" {
  name                  = "anyscale-data"
  storage_account_id    = azurerm_storage_account.example.id
  container_access_type = "private"
}