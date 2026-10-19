# ---------------------------------------------------------------------------
# Azure DNS zone for the public domain.
#
# The zone is expected to ALREADY EXIST with the domain's registrar
# nameservers delegated to it — that is the normal setup, and it means no
# manual delegation step is required. Terraform therefore looks the zone up by
# default (var.create_dns_zone = false).
#
# Set var.create_dns_zone = true to have Terraform create the zone in the new
# resource group instead. In that case you must delegate the nameservers at
# the registrar yourself before requesting a production Let's Encrypt
# certificate.
#
# The zone may live in a different subscription than the cluster
# (var.dns_zone_subscription_id); the `azurerm.dns` provider alias handles
# that, and the resolved subscription/resource group are threaded through to
# cert-manager's DNS-01 solver and to the A-record creation.
# ---------------------------------------------------------------------------

data "azurerm_dns_zone" "existing" {
  count = var.create_dns_zone ? 0 : 1

  provider            = azurerm.dns
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
}

resource "azurerm_dns_zone" "example" {
  count = var.create_dns_zone ? 1 : 0

  name                = var.dns_zone_name
  resource_group_name = azurerm_resource_group.example.name
  tags                = var.tags
}

# Advisory checks. A failed check emits a warning; it does not fail the apply.
check "dns_zone_configured" {
  assert {
    condition     = var.create_dns_zone || var.dns_zone_resource_group_name != ""
    error_message = "Set var.dns_zone_resource_group_name to the resource group holding the existing '${var.dns_zone_name}' zone (and var.dns_zone_subscription_id if the zone is in another subscription), or set var.create_dns_zone = true to have Terraform create it. Find the zone with: az network dns zone list --query \"[?name=='${var.dns_zone_name}'].{rg:resourceGroup,id:id}\" -o tsv"
  }
}

check "dns_delegation" {
  assert {
    condition     = !var.create_dns_zone
    error_message = "Terraform created the '${var.dns_zone_name}' Azure DNS zone. Before requesting a production Let's Encrypt certificate, delegate the domain's nameservers at the registrar to: ${join(", ", local.dns_zone_name_servers)}"
  }
}
