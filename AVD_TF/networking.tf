locals {
  create_vnet           = var.create_avd_vnet
  create_vnet_peering   = var.create_avd_vnet && length(trimspace(var.existing_hub_vnet_resource_id)) > 0
  hub_vnet_id_parts     = local.create_vnet_peering ? split("/", var.existing_hub_vnet_resource_id) : []
  hub_vnet_name         = local.create_vnet_peering ? local.hub_vnet_id_parts[8] : ""
  hub_vnet_rg           = local.create_vnet_peering ? local.hub_vnet_id_parts[4] : ""
}

resource "azurerm_network_ddos_protection_plan" "ddos" {
  count               = var.deploy_ddos_network_protection && local.create_vnet ? 1 : 0
  name                = local.ddos_plan_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_virtual_network" "avd" {
  count               = local.create_vnet ? 1 : 0
  name                = local.vnet_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  address_space       = [var.avd_vnetwork_address_prefixes]
  dns_servers         = local.custom_dns_servers
  tags                = local.resource_tags

  dynamic "ddos_protection_plan" {
    for_each = var.deploy_ddos_network_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.ddos[0].id
      enable = true
    }
  }
}

resource "azurerm_subnet" "avd" {
  count                = local.create_vnet ? 1 : 0
  name                 = local.vnet_avd_subnet_name
  resource_group_name  = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  virtual_network_name = azurerm_virtual_network.avd[0].name
  address_prefixes     = [var.vnetwork_avd_subnet_address_prefix]
  service_endpoints    = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "private_endpoints" {
  count                = local.create_vnet ? 1 : 0
  name                 = local.vnet_private_endpoint_subnet_name
  resource_group_name  = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  virtual_network_name = azurerm_virtual_network.avd[0].name
  address_prefixes     = [var.vnetwork_private_endpoint_subnet_address_prefix]
  private_endpoint_network_policies = "Disabled"
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

resource "azurerm_network_security_group" "avd" {
  count               = local.create_vnet ? 1 : 0
  name                = local.avd_nsg_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_network_security_group" "private_endpoints" {
  count               = local.create_vnet ? 1 : 0
  name                = local.private_endpoint_nsg_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_subnet_network_security_group_association" "avd" {
  count                     = local.create_vnet ? 1 : 0
  subnet_id                 = azurerm_subnet.avd[0].id
  network_security_group_id = azurerm_network_security_group.avd[0].id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  count                     = local.create_vnet ? 1 : 0
  subnet_id                 = azurerm_subnet.private_endpoints[0].id
  network_security_group_id = azurerm_network_security_group.private_endpoints[0].id
}

resource "azurerm_route_table" "avd" {
  count               = local.create_vnet ? 1 : 0
  name                = local.avd_route_table_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags

  dynamic "route" {
    for_each = var.custom_static_routes
    content {
      name                   = lookup(route.value, "name", "custom-${route.key}")
      address_prefix         = lookup(route.value, "address_prefix", null)
      next_hop_type          = lookup(route.value, "next_hop_type", "VirtualAppliance")
      next_hop_in_ip_address = lookup(route.value, "next_hop_in_ip_address", null)
    }
  }
}

resource "azurerm_route_table" "private_endpoints" {
  count               = local.create_vnet ? 1 : 0
  name                = local.private_endpoint_route_table_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_subnet_route_table_association" "avd" {
  count          = local.create_vnet ? 1 : 0
  subnet_id      = azurerm_subnet.avd[0].id
  route_table_id = azurerm_route_table.avd[0].id
}

resource "azurerm_subnet_route_table_association" "private_endpoints" {
  count          = local.create_vnet ? 1 : 0
  subnet_id      = azurerm_subnet.private_endpoints[0].id
  route_table_id = azurerm_route_table.private_endpoints[0].id
}

resource "azurerm_application_security_group" "avd" {
  count               = local.create_vnet ? 1 : 0
  name                = local.asg_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_virtual_network_peering" "vnet_to_hub" {
  count                        = local.create_vnet_peering ? 1 : 0
  name                         = "peer-${local.hub_vnet_name}"
  resource_group_name          = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  virtual_network_name         = azurerm_virtual_network.avd[0].name
  remote_virtual_network_id    = var.existing_hub_vnet_resource_id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.vnetwork_gateway_on_hub
}

resource "azurerm_virtual_network_peering" "hub_to_vnet" {
  count                        = local.create_vnet_peering ? 1 : 0
  name                         = "peer-${local.vnet_name}"
  resource_group_name          = local.hub_vnet_rg
  virtual_network_name         = local.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.avd[0].id
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.vnetwork_gateway_on_hub
}

data "azurerm_virtual_network" "existing" {
  count               = local.create_vnet ? 0 : 1
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

locals {
  vnet_id_for_dns = local.create_vnet ? azurerm_virtual_network.avd[0].id : data.azurerm_virtual_network.existing[0].id
}

resource "azurerm_private_dns_zone" "avd_connection" {
  count               = local.private_dns_zones_enabled && var.deploy_avd_private_link_service ? 1 : 0
  name                = local.dns_zone_avd_connection
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_private_dns_zone" "avd_discovery" {
  count               = local.private_dns_zones_enabled && var.deploy_avd_private_link_service ? 1 : 0
  name                = local.dns_zone_avd_discovery
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_private_dns_zone" "azure_files" {
  count               = local.private_dns_zones_enabled && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                = local.dns_zone_azure_files
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_private_dns_zone" "keyvault" {
  count               = local.private_dns_zones_enabled && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                = local.dns_zone_keyvault
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  tags                = local.resource_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "avd_connection" {
  count                 = local.private_dns_zones_enabled && var.deploy_avd_private_link_service ? 1 : 0
  name                  = "link-${local.dns_zone_avd_connection}"
  resource_group_name   = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.avd_connection[0].name
  virtual_network_id    = local.vnet_id_for_dns
}

resource "azurerm_private_dns_zone_virtual_network_link" "avd_discovery" {
  count                 = local.private_dns_zones_enabled && var.deploy_avd_private_link_service ? 1 : 0
  name                  = "link-${local.dns_zone_avd_discovery}"
  resource_group_name   = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.avd_discovery[0].name
  virtual_network_id    = local.vnet_id_for_dns
}

resource "azurerm_private_dns_zone_virtual_network_link" "azure_files" {
  count                 = local.private_dns_zones_enabled && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                  = "link-${local.dns_zone_azure_files}"
  resource_group_name   = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.azure_files[0].name
  virtual_network_id    = local.vnet_id_for_dns
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = local.private_dns_zones_enabled && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                  = "link-${local.dns_zone_keyvault}"
  resource_group_name   = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = local.vnet_id_for_dns
}
