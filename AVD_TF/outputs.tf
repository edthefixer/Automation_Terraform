output "resource_group_single" {
  description = "Single resource group name when enabled."
  value       = try(azurerm_resource_group.rg_single[0].name, null)
}

output "resource_group_service_objects" {
  description = "AVD service objects resource group name."
  value       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
}

output "resource_group_compute" {
  description = "AVD compute resource group name."
  value       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_compute[0].name
}

output "resource_group_network" {
  description = "AVD network resource group name (if created)."
  value       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : try(azurerm_resource_group.rg_network[0].name, null)
}

output "resource_group_storage" {
  description = "AVD storage resource group name (if created)."
  value       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : try(azurerm_resource_group.rg_storage[0].name, null)
}

output "resource_group_monitoring" {
  description = "AVD monitoring resource group name (if created)."
  value       = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : try(azurerm_resource_group.rg_monitoring[0].name, null)
}

output "hostpool_id" {
  description = "AVD host pool ID."
  value       = azurerm_virtual_desktop_host_pool.hostpool.id
}

output "workspace_id" {
  description = "AVD workspace ID."
  value       = azurerm_virtual_desktop_workspace.workspace.id
}

output "virtual_network_id" {
  description = "AVD virtual network ID (if created)."
  value       = try(azurerm_virtual_network.avd[0].id, null)
}

output "avd_subnet_id" {
  description = "AVD subnet ID."
  value       = local.session_host_subnet_id
}

output "private_endpoint_subnet_id" {
  description = "Private endpoint subnet ID."
  value       = try(azurerm_subnet.private_endpoints[0].id, null)
}

output "workload_key_vault_id" {
  description = "Workload Key Vault ID."
  value       = azurerm_key_vault.workload.id
}

output "zero_trust_key_vault_id" {
  description = "Zero trust Key Vault ID (if created)."
  value       = try(azurerm_key_vault.zero_trust[0].id, null)
}

output "disk_encryption_set_id" {
  description = "Disk encryption set ID (if created)."
  value       = try(azurerm_disk_encryption_set.zero_trust[0].id, null)
}

output "fslogix_storage_account_id" {
  description = "FSLogix storage account ID (if created)."
  value       = try(azurerm_storage_account.fslogix[0].id, null)
}

output "app_attach_storage_account_id" {
  description = "App Attach storage account ID (if created)."
  value       = try(azurerm_storage_account.app_attach[0].id, null)
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID (if created)."
  value       = try(azurerm_log_analytics_workspace.avd[0].id, null)
}

output "scaling_plan_id" {
  description = "AVD scaling plan ID (if created)."
  value       = try(azurerm_virtual_desktop_scaling_plan.plan[0].id, null)
}

output "session_host_names" {
  description = "Session host VM names."
  value       = [for vm in azurerm_windows_virtual_machine.session_host : vm.name]
}
