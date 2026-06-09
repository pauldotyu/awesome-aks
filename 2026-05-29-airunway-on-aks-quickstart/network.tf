resource "azurerm_virtual_network" "example" {
  name                = "vnet-msbuildlab510${random_string.example.result}"
  address_space       = ["10.21.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "time_sleep" "wait_for_vnet" {
  depends_on      = [azurerm_virtual_network.example]
  create_duration = "30s"
}

resource "azurerm_subnet" "lfs" {
  name                 = "lustre"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.21.1.0/24"]

  depends_on = [time_sleep.wait_for_vnet]
}

resource "azurerm_subnet" "aks_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.21.2.0/24"]

  depends_on = [time_sleep.wait_for_vnet]
}

resource "azurerm_subnet" "aks_inference" {
  name                 = "inference"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.21.3.0/24"]

  depends_on = [time_sleep.wait_for_vnet]
}