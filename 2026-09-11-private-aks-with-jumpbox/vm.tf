resource "azurerm_role_assignment" "windows_vm_administrator_login" {
  scope                = azurerm_windows_virtual_machine.example.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_network_interface" "example" {
  name                = "nic-${local.random_name}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jump.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "vm-${local.random_name}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_D4ds_v5"
  admin_username      = var.admin_username
  admin_password      = random_password.example.result

  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-25h2-pro"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# // https://learn.microsoft.com/entra/identity/devices/howto-vm-sign-in-azure-ad-windows?pivots=identity-extension-vm#enable-microsoft-entra-sign-in-extension
# resource "azurerm_virtual_machine_extension" "example" {
#   name                       = "${azurerm_windows_virtual_machine.example.name}-aadlogin"
#   virtual_machine_id         = azurerm_windows_virtual_machine.example.id
#   publisher                  = "Microsoft.Azure.ActiveDirectory"
#   type                       = "AADLoginForWindows"
#   type_handler_version       = "1.0"
#   auto_upgrade_minor_version = true
# }
