locals {
  deployment_prefix_lower           = lower(var.deployment_prefix)
  deployment_environment_lower      = lower(var.deployment_environment)
  management_plane_location         = coalesce(var.avd_management_plane_location, var.location)
  session_host_location             = coalesce(var.avd_session_host_location, var.location)
  management_plane_location_short   = coalesce(var.management_plane_location_short, var.location_short)
  session_host_location_short       = coalesce(var.session_host_location_short, var.location_short)
  naming_standard_management_plane  = "${local.deployment_prefix_lower}-${local.deployment_environment_lower}-${local.management_plane_location_short}"
  naming_standard_compute_storage   = "${local.deployment_prefix_lower}-${local.deployment_environment_lower}-${local.session_host_location_short}"
  use_custom_naming                 = var.avd_use_custom_naming
  use_single_rg                     = var.use_single_resource_group
  time_value                        = coalesce(var.time, timestamp())

  service_objects_rg_name  = local.use_custom_naming ? var.avd_service_objects_rg_custom_name : "rg-avd-${local.naming_standard_management_plane}-service-objects"
  compute_objects_rg_name  = local.use_custom_naming ? var.avd_compute_objects_rg_custom_name : "rg-avd-${local.naming_standard_compute_storage}-pool-compute"
  network_objects_rg_name  = local.use_custom_naming ? var.avd_network_objects_rg_custom_name : "rg-avd-${local.naming_standard_compute_storage}-network"
  storage_objects_rg_name  = local.use_custom_naming ? var.avd_storage_objects_rg_custom_name : "rg-avd-${local.naming_standard_compute_storage}-storage"
  monitoring_rg_name       = local.use_custom_naming ? var.avd_monitoring_rg_custom_name : "rg-avd-${local.deployment_environment_lower}-${local.management_plane_location_short}-monitoring"

  single_rg_name = length(trimspace(var.single_resource_group_name)) > 0 ? var.single_resource_group_name : "rg-avd-${local.naming_standard_management_plane}-all"

  workspace_name           = local.use_custom_naming ? var.avd_workspace_custom_name : "vdws-${local.naming_standard_management_plane}-001"
  host_pool_name           = local.use_custom_naming ? var.avd_hostpool_custom_name : "vdpool-${local.naming_standard_management_plane}-001"
  preferred_app_group_type = lower(var.host_pool_preferred_app_group_type)
  app_group_name           = local.use_custom_naming ? var.avd_application_group_custom_name : "vdag-${local.preferred_app_group_type}-${local.naming_standard_management_plane}-001"

  session_host_name_prefix = local.use_custom_naming ? var.avd_session_host_custom_name_prefix : "vm${local.deployment_prefix_lower}${substr(local.deployment_environment_lower, 0, 1)}${local.session_host_location_short}"

  create_storage_deployment = var.create_avd_fslogix_deployment || var.create_app_attach_deployment

  tag_candidates = {
    WorkloadName     = var.workload_name_tag
    WorkloadType     = var.workload_type_tag
    DataClassification = var.data_classification_tag
    Department       = var.department_tag
    Criticality      = var.workload_criticality_tag == "Custom" ? var.workload_criticality_custom_value_tag : var.workload_criticality_tag
    ApplicationName  = var.application_name_tag
    ServiceClass     = var.workload_sla_tag
    OpsTeam          = var.ops_team_tag
    Owner            = var.owner_tag
    CostCenter       = var.cost_center_tag
  }

  custom_resource_tags = var.create_resource_tags ? { for k, v in local.tag_candidates : k => v if v != "" } : {}

  avd_default_tags = {
    Environment   = var.deployment_environment
    ServiceWorkload = "AVD"
    CreationTimeUTC = local.time_value
  }

  resource_tags = merge(local.avd_default_tags, local.custom_resource_tags, var.tags)

  unique_suffix = substr(md5(local.time_value), 0, 3)
  env_short     = substr(local.deployment_environment_lower, 0, 1)

  vnet_name                   = local.use_custom_naming ? var.avd_vnetwork_custom_name : "vnet-${local.naming_standard_compute_storage}-001"
  vnet_avd_subnet_name         = local.use_custom_naming ? var.avd_vnetwork_subnet_custom_name : "snet-avd-${local.naming_standard_compute_storage}-001"
  vnet_private_endpoint_subnet_name = local.use_custom_naming ? var.private_endpoint_vnetwork_subnet_custom_name : "snet-pe-${local.naming_standard_compute_storage}-001"
  avd_nsg_name                 = local.use_custom_naming ? var.avd_network_security_group_custom_name : "nsg-avd-${local.naming_standard_compute_storage}-001"
  private_endpoint_nsg_name    = local.use_custom_naming ? var.private_endpoint_network_security_group_custom_name : "nsg-pe-${local.naming_standard_compute_storage}-001"
  avd_route_table_name         = local.use_custom_naming ? var.avd_route_table_custom_name : "route-avd-${local.naming_standard_compute_storage}-001"
  private_endpoint_route_table_name = local.use_custom_naming ? var.private_endpoint_route_table_custom_name : "route-pe-${local.naming_standard_compute_storage}-001"
  asg_name                     = local.use_custom_naming ? var.avd_application_security_group_custom_name : "asg-${local.naming_standard_compute_storage}-001"
  ddos_plan_name               = "ddos-${local.vnet_name}"

  workspace_friendly_name      = local.use_custom_naming ? var.avd_workspace_custom_friendly_name : "Workspace ${var.deployment_prefix} ${var.deployment_environment} ${local.management_plane_location} 001"
  host_pool_friendly_name      = local.use_custom_naming ? var.avd_hostpool_custom_friendly_name : "Hostpool ${var.deployment_prefix} ${var.deployment_environment} ${local.management_plane_location} 001"
  app_group_friendly_name      = local.use_custom_naming ? var.avd_application_group_custom_friendly_name : "${var.host_pool_preferred_app_group_type} ${var.deployment_prefix} ${var.deployment_environment} ${local.management_plane_location} 001"

  scaling_plan_name            = local.use_custom_naming ? var.avd_scaling_plan_custom_name : "vdscaling-${local.naming_standard_management_plane}-001"
  scaling_plan_weekdays_name   = "Weekdays-${local.naming_standard_management_plane}"
  scaling_plan_weekend_name    = "Weekend-${local.naming_standard_management_plane}"

  storage_account_prefix       = local.use_custom_naming ? var.storage_account_prefix_custom_name : "st"
  fslogix_storage_name_raw     = "${local.storage_account_prefix}fsl${local.deployment_prefix_lower}${local.env_short}${local.unique_suffix}"
  app_attach_storage_name_raw  = "${local.storage_account_prefix}appa${local.deployment_prefix_lower}${local.env_short}${local.unique_suffix}"
  fslogix_storage_name         = lower(replace(local.fslogix_storage_name_raw, "-", ""))
  app_attach_storage_name      = lower(replace(local.app_attach_storage_name_raw, "-", ""))
  fslogix_file_share_name      = local.use_custom_naming ? var.fslogix_file_share_custom_name : "fslogix-pc-${local.deployment_prefix_lower}-${local.deployment_environment_lower}-${local.session_host_location_short}-001"
  app_attach_file_share_name   = local.use_custom_naming ? var.app_attach_file_share_custom_name : "appa-${local.deployment_prefix_lower}-${local.deployment_environment_lower}-${local.session_host_location_short}-001"

  workload_kv_name_raw         = local.use_custom_naming ? var.avd_wrkl_kv_prefix_custom_name : "kv-sec"
  zt_kv_name_raw               = local.use_custom_naming ? var.zt_kv_prefix_custom_name : "kv-key"
  workload_kv_name             = substr(lower(replace("${local.workload_kv_name_raw}-${local.naming_standard_compute_storage}-${substr(local.unique_suffix, 0, 2)}", "-", "")), 0, 24)
  zt_kv_name                   = substr(lower(replace("${local.zt_kv_name_raw}-${local.naming_standard_compute_storage}-${substr(local.unique_suffix, 0, 2)}", "-", "")), 0, 24)

  private_dns_zones_enabled    = var.create_private_dns_zones && (var.deploy_private_endpoint_keyvault_storage || var.deploy_avd_private_link_service)
  dns_zone_avd_connection      = "privatelink.wvd.azure.com"
  dns_zone_avd_discovery       = "privatelink-global.wvd.azure.com"
  dns_zone_azure_files         = "privatelink.file.core.windows.net"
  dns_zone_keyvault            = "privatelink.vaultcore.azure.net"

  custom_dns_servers           = length(trimspace(var.custom_dns_ips)) > 0 ? concat(split(",", replace(var.custom_dns_ips, " ", "")), ["168.63.129.16"]) : []
}
