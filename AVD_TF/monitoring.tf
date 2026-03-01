locals {
  monitoring_enabled = var.avd_deploy_monitoring
  ala_workspace_id   = var.avd_deploy_monitoring ? (var.deploy_ala_workspace ? azurerm_log_analytics_workspace.avd[0].id : var.ala_existing_workspace_resource_id) : null
  monitoring_ready   = local.monitoring_enabled && local.ala_workspace_id != null && length(trim(local.ala_workspace_id, " ")) > 0
}

resource "azurerm_log_analytics_workspace" "avd" {
  count               = var.avd_deploy_monitoring && var.deploy_ala_workspace ? 1 : 0
  name                = local.use_custom_naming ? var.avd_ala_workspace_custom_name : "log-avd-${local.deployment_environment_lower}-${local.management_plane_location_short}"
  location            = local.management_plane_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_monitoring[0].name
  sku                 = "PerGB2018"
  retention_in_days   = var.avd_ala_workspace_data_retention
  tags                = local.resource_tags
}

resource "azurerm_monitor_diagnostic_setting" "hostpool" {
  count                      = local.monitoring_ready ? 1 : 0
  name                       = "diag-${azurerm_virtual_desktop_host_pool.hostpool.name}"
  target_resource_id         = azurerm_virtual_desktop_host_pool.hostpool.id
  log_analytics_workspace_id = local.ala_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "workspace" {
  count                      = local.monitoring_ready ? 1 : 0
  name                       = "diag-${azurerm_virtual_desktop_workspace.workspace.name}"
  target_resource_id         = azurerm_virtual_desktop_workspace.workspace.id
  log_analytics_workspace_id = local.ala_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "fslogix" {
  count                      = local.monitoring_ready && var.create_avd_fslogix_deployment ? 1 : 0
  name                       = "diag-${azurerm_storage_account.fslogix[0].name}"
  target_resource_id         = azurerm_storage_account.fslogix[0].id
  log_analytics_workspace_id = local.ala_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "app_attach" {
  count                      = local.monitoring_ready && var.create_app_attach_deployment ? 1 : 0
  name                       = "diag-${azurerm_storage_account.app_attach[0].name}"
  target_resource_id         = azurerm_storage_account.app_attach[0].id
  log_analytics_workspace_id = local.ala_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
