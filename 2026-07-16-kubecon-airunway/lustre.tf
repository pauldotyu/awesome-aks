resource "azurerm_managed_lustre_file_system" "example" {
  name                   = "lfs-${local.random_name}"
  resource_group_name    = azurerm_resource_group.example.name
  location               = azurerm_resource_group.example.location
  sku_name               = "AMLFS-Durable-Premium-500"
  subnet_id              = azurerm_subnet.lfs.id
  storage_capacity_in_tb = 4
  zones                  = ["2"]

  maintenance_window {
    day_of_week        = "Sunday"
    time_of_day_in_utc = "22:00"
  }
}

resource "local_file" "azurelustre_storageclass" {
  filename = "azurelustre-static.yaml"
  content = templatefile("azurelustre-static.tmpl",
    {
      MGS_IP_ADDRESS = azurerm_managed_lustre_file_system.example.mgs_address
    }
  )
}