# Run AVD prerequisites validation before deployment
resource "null_resource" "avd_prerequisites_validation" {
  provisioner "local-exec" {
    command = "pwsh ./AVD_Prerequisites_Setup.ps1"
  }
}

# Wait for AVD session hosts to become available after deployment
resource "null_resource" "wait_for_avd_hosts" {
  provisioner "local-exec" {
    command = "pwsh ./AVD_Wait-for-avd-hosts.ps1 -ResourceGroup ${local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name} -HostPoolName ${azurerm_virtual_desktop_host_pool.hostpool.name} -TimeoutMinutes 20"
  }
  depends_on = [azurerm_windows_virtual_machine.session_host]
}
resource "azurerm_resource_group" "rg_single" {
  count    = local.use_single_rg ? 1 : 0
  name     = local.single_rg_name
  location = local.management_plane_location
  tags     = local.resource_tags
}

resource "azurerm_resource_group" "rg_service_objects" {
  count    = local.use_single_rg ? 0 : 1
  name     = local.service_objects_rg_name
  location = local.management_plane_location
  tags     = local.resource_tags
}

resource "azurerm_resource_group" "rg_compute" {
  count    = local.use_single_rg ? 0 : 1
  name     = local.compute_objects_rg_name
  location = local.session_host_location
  tags     = local.resource_tags
}

resource "azurerm_resource_group" "rg_network" {
  count    = local.use_single_rg ? 0 : (var.create_avd_vnet || var.create_private_dns_zones || var.deploy_private_endpoint_keyvault_storage || var.deploy_avd_private_link_service ? 1 : 0)
  name     = local.network_objects_rg_name
  location = local.session_host_location
  tags     = local.resource_tags
}

resource "azurerm_resource_group" "rg_storage" {
  count    = local.use_single_rg ? 0 : (local.create_storage_deployment ? 1 : 0)
  name     = local.storage_objects_rg_name
  location = local.session_host_location
  tags     = local.resource_tags
}

resource "azurerm_resource_group" "rg_monitoring" {
  count    = local.use_single_rg ? 0 : (var.avd_deploy_monitoring ? 1 : 0)
  name     = local.monitoring_rg_name
  location = local.management_plane_location
  tags     = local.resource_tags
}

resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                = local.host_pool_name
  location            = local.use_single_rg ? azurerm_resource_group.rg_single[0].location : azurerm_resource_group.rg_service_objects[0].location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
  type                = var.avd_host_pool_type
  load_balancer_type  = var.avd_host_pool_load_balancer_type
  friendly_name       = local.host_pool_friendly_name
  custom_rdp_properties = var.avd_host_pool_rdp_properties
  start_vm_on_connect = var.avd_start_vm_on_connect
  maximum_sessions_allowed = var.host_pool_max_sessions
  personal_desktop_assignment_type = var.avd_host_pool_type == "Personal" ? var.avd_personal_assign_type : null
  public_network_access = var.host_pool_public_network_access
  tags                = local.resource_tags
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = coalesce(var.registration_expiration, timeadd(timestamp(), "168h"))
}

locals {
  avd_registration_token = azurerm_virtual_desktop_host_pool_registration_info.registration.token
  enable_domain_join     = contains(["ADDS", "EntraDS"], var.avd_identity_service_provider)
}

resource "azurerm_virtual_desktop_application_group" "primary" {
  name                = local.app_group_name
  location            = local.use_single_rg ? azurerm_resource_group.rg_single[0].location : azurerm_resource_group.rg_service_objects[0].location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
  type                = var.host_pool_preferred_app_group_type
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name       = local.app_group_friendly_name
  tags                = local.resource_tags
}

resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = local.workspace_name
  location            = local.use_single_rg ? azurerm_resource_group.rg_single[0].location : azurerm_resource_group.rg_service_objects[0].location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
  friendly_name       = local.workspace_friendly_name
  tags                = local.resource_tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "primary_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.primary.id
}

locals {
  use_existing_subnet = !var.create_avd_vnet && length(trimspace(var.existing_vnet_avd_subnet_resource_id)) > 0
}

data "azurerm_subnet" "existing_subnet" {
  count                = var.create_avd_vnet ? 0 : (local.use_existing_subnet ? 0 : 1)
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group
}

locals {
  session_host_subnet_id = var.create_avd_vnet ? azurerm_subnet.avd[0].id : (local.use_existing_subnet ? var.existing_vnet_avd_subnet_resource_id : data.azurerm_subnet.existing_subnet[0].id)
  disk_encryption_set_id = var.disk_zero_trust ? azurerm_disk_encryption_set.zero_trust[0].id : null
}

resource "azurerm_network_interface" "nic" {
  count               = var.avd_deploy_session_hosts ? var.avd_deploy_session_hosts_count : 0
  name                = "${local.session_host_name_prefix}-${format("%04d", var.avd_session_host_count_index + count.index)}-nic"
  location            = local.use_single_rg ? azurerm_resource_group.rg_single[0].location : azurerm_resource_group.rg_compute[0].location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_compute[0].name
  tags                = local.resource_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = local.session_host_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "session_host" {
    identity {
      type = "SystemAssigned"
    }
  count               = var.avd_deploy_session_hosts ? var.avd_deploy_session_hosts_count : 0
  name                = "${local.session_host_name_prefix}-${format("%04d", var.avd_session_host_count_index + count.index)}"
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_compute[0].name
  location            = local.use_single_rg ? azurerm_resource_group.rg_single[0].location : azurerm_resource_group.rg_compute[0].location
  size                = var.avd_session_hosts_size
  tags                = local.resource_tags
  zone                = var.availability == "AvailabilityZones" ? element(var.availability_zones, count.index % length(var.availability_zones)) : null

  admin_username = var.avd_vm_local_user_name
  admin_password = var.avd_vm_local_user_password

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  encryption_at_host_enabled = var.disk_zero_trust

  os_disk {
    caching                = "ReadWrite"
    storage_account_type   = var.avd_session_host_disk_type
    disk_encryption_set_id = local.disk_encryption_set_id
    disk_size_gb           = var.custom_os_disk_size_gb > 0 ? var.custom_os_disk_size_gb : null
  }

  source_image_id = var.use_shared_image ? var.avd_custom_image_definition_id : null

  dynamic "source_image_reference" {
    for_each = var.use_shared_image ? [] : [1]
    content {
      publisher = "MicrosoftWindowsDesktop"
      offer     = var.mp_image_offer
      sku       = var.mp_image_sku
      version   = "latest"
    }
  }
}

resource "azurerm_virtual_machine_extension" "aad_login" {
  count = var.avd_deploy_session_hosts && (var.avd_identity_service_provider == "EntraID" || var.avd_identity_service_provider == "EntraIDKerberos") ? var.avd_deploy_session_hosts_count : 0
  name                 = "AADLoginForWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADLoginForWindows"
  type_handler_version = "2.2"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "domain_join" {
  count                = var.avd_deploy_session_hosts && (var.avd_identity_service_provider == "ADDS" || var.avd_identity_service_provider == "EntraDS") ? var.avd_deploy_session_hosts_count : 0
  name                 = "joindomain"
  virtual_machine_id   = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = <<SETTINGS
{
  "Name": "${var.identity_domain_name}",
  "OUPath": "${var.avd_ou_path}",
  "User": "${var.avd_domain_join_user_name}",
  "Restart": "true",
  "Options": "3"
}
SETTINGS

  protected_settings = <<PROTECTED
{
  "Password": "${var.avd_domain_join_user_password}"
}
PROTECTED
}

resource "azurerm_virtual_machine_extension" "avd_register" {
  count                      = var.enable_avd_registration && var.avd_deploy_session_hosts ? var.avd_deploy_session_hosts_count : 0
  name                       = "Microsoft.Powershell.DSC"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
{
  "modulesUrl": "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02714.342.zip",
  "configurationFunction": "Configuration.ps1\\AddSessionHost",
  "properties": {
    "HostPoolName": "${azurerm_virtual_desktop_host_pool.hostpool.name}"
  }
}
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
{
  "properties": {
    "registrationInfoToken": "${local.avd_registration_token}"
  }
}
PROTECTED_SETTINGS

  depends_on = [
    azurerm_virtual_desktop_host_pool.hostpool,
    azurerm_virtual_machine_extension.domain_join
  ]
}
