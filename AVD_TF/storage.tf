locals {
  private_endpoint_subnet_id = var.create_avd_vnet ? azurerm_subnet.private_endpoints[0].id : var.existing_vnet_private_endpoint_subnet_resource_id

  azure_files_dns_zone_id = local.private_dns_zones_enabled ? azurerm_private_dns_zone.azure_files[0].id : var.avd_vnet_private_dns_zone_files_id

  keyvault_dns_zone_id = local.private_dns_zones_enabled ? azurerm_private_dns_zone.keyvault[0].id : var.avd_vnet_private_dns_zone_keyvault_id

  vm_secrets_enabled       = var.avd_vm_local_user_name != null && var.avd_vm_local_user_password != null
  domain_join_secrets_used = !strcontains(var.avd_identity_service_provider, "EntraID")

  fslogix_replication_type = var.zone_redundant_storage ? "ZRS" : "LRS"
  app_attach_replication_type = var.zone_redundant_storage ? "ZRS" : "LRS"
}

resource "azurerm_key_vault" "workload" {
  name                = local.workload_kv_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  rbac_authorization_enabled     = true
  purge_protection_enabled      = var.enable_kv_purge_protection
  soft_delete_retention_days    = 7
  public_network_access_enabled = var.key_vault_public_network_access_enabled

  network_acls {
    bypass                     = "AzureServices"
    default_action             = var.key_vault_public_network_access_enabled ? "Allow" : "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = var.deploy_private_endpoint_keyvault_storage ? [] : [local.session_host_subnet_id]
  }

  tags = merge(local.resource_tags, { Purpose = "Secrets for local admin and domain join credentials" })
}

resource "azurerm_role_assignment" "kv_secrets_officer_workload" {
  scope                = azurerm_key_vault.workload.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "vm_local_username" {
  count        = local.vm_secrets_enabled ? 1 : 0
  name         = "vmLocalUserName"
  value        = var.avd_vm_local_user_name
  key_vault_id = azurerm_key_vault.workload.id
  content_type = "Session host local user credentials"
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_workload]
}

resource "azurerm_key_vault_secret" "vm_local_password" {
  count        = local.vm_secrets_enabled ? 1 : 0
  name         = "vmLocalUserPassword"
  value        = var.avd_vm_local_user_password
  key_vault_id = azurerm_key_vault.workload.id
  content_type = "Session host local user credentials"
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_workload]
}

resource "azurerm_key_vault_secret" "domain_join_username" {
  count        = local.vm_secrets_enabled ? 1 : 0
  name         = "domainJoinUserName"
  value        = local.domain_join_secrets_used ? var.avd_domain_join_user_name : "NoUsername"
  key_vault_id = azurerm_key_vault.workload.id
  content_type = "Domain join credentials"
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_workload]
}

resource "azurerm_key_vault_secret" "domain_join_password" {
  count        = local.vm_secrets_enabled ? 1 : 0
  name         = "domainJoinUserPassword"
  value        = local.domain_join_secrets_used ? var.avd_domain_join_user_password : "NoPassword"
  key_vault_id = azurerm_key_vault.workload.id
  content_type = "Domain join credentials"
  depends_on   = [azurerm_role_assignment.kv_secrets_officer_workload]
}

resource "azurerm_private_endpoint" "workload_kv" {
  count               = var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                = "pe-${local.workload_kv_name}-vault"
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  subnet_id           = local.private_endpoint_subnet_id
  tags                = local.resource_tags

  private_service_connection {
    name                           = "psc-${local.workload_kv_name}"
    private_connection_resource_id = azurerm_key_vault.workload.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.create_private_dns_zones || length(trim(var.avd_vnet_private_dns_zone_keyvault_id, " ")) > 0 ? [1] : []
    content {
      name                 = "pdzg-kv"
      private_dns_zone_ids = [local.keyvault_dns_zone_id]
    }
  }
}

resource "azurerm_storage_account" "fslogix" {
  count                     = var.create_avd_fslogix_deployment ? 1 : 0
  name                      = local.fslogix_storage_name
  resource_group_name       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_storage[0].name
  location                  = local.session_host_location
  account_tier              = var.fslogix_storage_performance
  account_replication_type  = local.fslogix_replication_type
  account_kind              = var.fslogix_storage_performance == "Premium" ? "FileStorage" : "StorageV2"
  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"
  public_network_access_enabled = var.storage_public_network_access_enabled
  tags                      = local.resource_tags
}

resource "azurerm_storage_share" "fslogix" {
  count                = var.create_avd_fslogix_deployment ? 1 : 0
  name                 = local.fslogix_file_share_name
  storage_account_id   = azurerm_storage_account.fslogix[0].id
  quota                = var.fslogix_file_share_quota_size * 1024

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_private_endpoint" "fslogix" {
  count               = var.create_avd_fslogix_deployment && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                = "pe-${local.fslogix_storage_name}-files"
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  subnet_id           = local.private_endpoint_subnet_id
  tags                = local.resource_tags

  private_service_connection {
    name                           = "psc-${local.fslogix_storage_name}"
    private_connection_resource_id = azurerm_storage_account.fslogix[0].id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.create_private_dns_zones || length(trim(var.avd_vnet_private_dns_zone_files_id, " ")) > 0 ? [1] : []
    content {
      name                 = "pdzg-files"
      private_dns_zone_ids = [local.azure_files_dns_zone_id]
    }
  }
}

resource "azurerm_storage_account" "app_attach" {
  count                     = var.create_app_attach_deployment ? 1 : 0
  name                      = local.app_attach_storage_name
  resource_group_name       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_storage[0].name
  location                  = local.session_host_location
  account_tier              = var.app_attach_storage_performance
  account_replication_type  = local.app_attach_replication_type
  account_kind              = var.app_attach_storage_performance == "Premium" ? "FileStorage" : "StorageV2"
  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"
  public_network_access_enabled = var.storage_public_network_access_enabled
  tags                      = local.resource_tags
}

resource "azurerm_storage_share" "app_attach" {
  count                = var.create_app_attach_deployment ? 1 : 0
  name                 = local.app_attach_file_share_name
  storage_account_id   = azurerm_storage_account.app_attach[0].id
  quota                = var.app_attach_file_share_quota_size * 1024

  lifecycle {
    ignore_changes = all
  }
}

resource "azurerm_private_endpoint" "app_attach" {
  count               = var.create_app_attach_deployment && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                = "pe-${local.app_attach_storage_name}-files"
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  subnet_id           = local.private_endpoint_subnet_id
  tags                = local.resource_tags

  private_service_connection {
    name                           = "psc-${local.app_attach_storage_name}"
    private_connection_resource_id = azurerm_storage_account.app_attach[0].id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.create_private_dns_zones || length(trim(var.avd_vnet_private_dns_zone_files_id, " ")) > 0 ? [1] : []
    content {
      name                 = "pdzg-files"
      private_dns_zone_ids = [local.azure_files_dns_zone_id]
    }
  }
}

resource "azurerm_key_vault" "zero_trust" {
  count               = var.disk_zero_trust ? 1 : 0
  name                = local.zt_kv_name
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  rbac_authorization_enabled     = true
  purge_protection_enabled      = var.enable_kv_purge_protection
  soft_delete_retention_days    = 7
  public_network_access_enabled = var.key_vault_public_network_access_enabled

  network_acls {
    bypass                     = "AzureServices"
    default_action             = var.key_vault_public_network_access_enabled ? "Allow" : "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = var.deploy_private_endpoint_keyvault_storage ? [] : [local.session_host_subnet_id]
  }

  tags = merge(local.resource_tags, { Purpose = "Disk encryption keys for zero trust" })
}

resource "azurerm_role_assignment" "kv_secrets_officer_zero_trust" {
  count                = var.disk_zero_trust ? 1 : 0
  scope                = azurerm_key_vault.zero_trust[0].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "zero_trust" {
  count        = var.disk_zero_trust ? 1 : 0
  name         = "disk-encryption"
  key_vault_id = azurerm_key_vault.zero_trust[0].id
  key_type     = "RSA"
  key_size     = 2048
  expiration_date = timeadd(local.time_value, "${var.disk_encryption_key_expiration_in_days}d")

  key_opts = [
    "encrypt",
    "decrypt",
    "wrapKey",
    "unwrapKey",
    "sign",
    "verify"
  ]
}

resource "azurerm_disk_encryption_set" "zero_trust" {
  count               = var.disk_zero_trust ? 1 : 0
  name                = "${var.zt_disk_encryption_set_custom_name_prefix}-${local.naming_standard_compute_storage}-001"
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_compute[0].name
  location            = local.session_host_location
  key_vault_key_id     = azurerm_key_vault_key.zero_trust[0].id

  identity {
    type = "SystemAssigned"
  }

  tags = local.resource_tags
}

data "azurerm_role_definition" "kv_crypto_user" {
  count = var.disk_zero_trust ? 1 : 0
  name  = "Key Vault Crypto Service Encryption User"
  scope = azurerm_key_vault.zero_trust[0].id
}

resource "azurerm_role_assignment" "des_kv" {
  count              = var.disk_zero_trust ? 1 : 0
  scope              = azurerm_key_vault.zero_trust[0].id
  role_definition_id = data.azurerm_role_definition.kv_crypto_user[0].id
  principal_id       = azurerm_disk_encryption_set.zero_trust[0].identity[0].principal_id
}

resource "azurerm_private_endpoint" "zero_trust_kv" {
  count               = var.disk_zero_trust && var.deploy_private_endpoint_keyvault_storage ? 1 : 0
  name                = "pe-${local.zt_kv_name}-vault"
  location            = local.session_host_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_network[0].name
  subnet_id           = local.private_endpoint_subnet_id
  tags                = local.resource_tags

  private_service_connection {
    name                           = "psc-${local.zt_kv_name}"
    private_connection_resource_id = azurerm_key_vault.zero_trust[0].id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.create_private_dns_zones || length(trim(var.avd_vnet_private_dns_zone_keyvault_id, " ")) > 0 ? [1] : []
    content {
      name                 = "pdzg-kv"
      private_dns_zone_ids = [local.keyvault_dns_zone_id]
    }
  }
}
