locals {
  scaling_plan_enabled = var.avd_deploy_scaling_plan && length(trimspace(var.avd_service_principal_object_id)) > 0

  pooled_scaling_plan_schedules = [
    {
      name                             = local.scaling_plan_weekdays_name
      days_of_week                     = ["Monday", "Wednesday", "Thursday", "Friday"]
      ramp_up_start_time               = "07:00"
      ramp_up_load_balancing_algorithm = "DepthFirst"
      ramp_up_capacity_threshold_percent = 80
      ramp_up_minimum_hosts_percent    = 20
      peak_start_time                  = "09:00"
      peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time             = "18:00"
      ramp_down_load_balancing_algorithm = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_force_logoff_users     = true
      ramp_down_minimum_hosts_percent  = 0
      ramp_down_notification_message   = "You will be logged off in 30 min. Make sure to save your work."
      ramp_down_wait_time_minutes      = 30
      ramp_down_stop_hosts_when        = "ZeroActiveSessions"
      off_peak_start_time              = "20:00"
      off_peak_load_balancing_algorithm = "DepthFirst"
    },
    {
      name                             = "${local.scaling_plan_weekdays_name}-agent-updates"
      days_of_week                     = ["Tuesday"]
      ramp_up_start_time               = "07:00"
      ramp_up_load_balancing_algorithm = "DepthFirst"
      ramp_up_capacity_threshold_percent = 80
      ramp_up_minimum_hosts_percent    = 20
      peak_start_time                  = "09:00"
      peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time             = "19:00"
      ramp_down_load_balancing_algorithm = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_force_logoff_users     = true
      ramp_down_minimum_hosts_percent  = 0
      ramp_down_notification_message   = "You will be logged off in 30 min. Make sure to save your work."
      ramp_down_wait_time_minutes      = 30
      ramp_down_stop_hosts_when        = "ZeroActiveSessions"
      off_peak_start_time              = "20:00"
      off_peak_load_balancing_algorithm = "DepthFirst"
    },
    {
      name                             = local.scaling_plan_weekend_name
      days_of_week                     = ["Saturday", "Sunday"]
      ramp_up_start_time               = "09:00"
      ramp_up_load_balancing_algorithm = "DepthFirst"
      ramp_up_capacity_threshold_percent = 90
      ramp_up_minimum_hosts_percent    = 0
      peak_start_time                  = "10:00"
      peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time             = "16:00"
      ramp_down_load_balancing_algorithm = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_force_logoff_users     = true
      ramp_down_minimum_hosts_percent  = 0
      ramp_down_notification_message   = "You will be logged off in 30 min. Make sure to save your work."
      ramp_down_wait_time_minutes      = 30
      ramp_down_stop_hosts_when        = "ZeroActiveSessions"
      off_peak_start_time              = "18:00"
      off_peak_load_balancing_algorithm = "DepthFirst"
    }
  ]

  personal_scaling_plan_schedules = [
    {
      name                             = local.scaling_plan_weekdays_name
      days_of_week                     = ["Monday", "Wednesday", "Thursday", "Friday"]
      ramp_up_start_time               = "07:00"
      ramp_up_load_balancing_algorithm = "DepthFirst"
      ramp_up_capacity_threshold_percent = 80
      ramp_up_minimum_hosts_percent    = 20
      peak_start_time                  = "09:00"
      peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time             = "18:00"
      ramp_down_load_balancing_algorithm = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_force_logoff_users     = true
      ramp_down_minimum_hosts_percent  = 0
      ramp_down_notification_message   = "You will be logged off in 30 min. Make sure to save your work."
      ramp_down_wait_time_minutes      = 30
      ramp_down_stop_hosts_when        = "ZeroActiveSessions"
      off_peak_start_time              = "20:00"
      off_peak_load_balancing_algorithm = "DepthFirst"
    },
    {
      name                             = "${local.scaling_plan_weekdays_name}-agent-updates"
      days_of_week                     = ["Tuesday"]
      ramp_up_start_time               = "07:00"
      ramp_up_load_balancing_algorithm = "DepthFirst"
      ramp_up_capacity_threshold_percent = 80
      ramp_up_minimum_hosts_percent    = 20
      peak_start_time                  = "09:00"
      peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time             = "19:00"
      ramp_down_load_balancing_algorithm = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_force_logoff_users     = true
      ramp_down_minimum_hosts_percent  = 0
      ramp_down_notification_message   = "You will be logged off in 30 min. Make sure to save your work."
      ramp_down_wait_time_minutes      = 30
      ramp_down_stop_hosts_when        = "ZeroActiveSessions"
      off_peak_start_time              = "20:00"
      off_peak_load_balancing_algorithm = "DepthFirst"
    },
    {
      name                             = local.scaling_plan_weekend_name
      days_of_week                     = ["Saturday", "Sunday"]
      ramp_up_start_time               = "09:00"
      ramp_up_load_balancing_algorithm = "DepthFirst"
      ramp_up_capacity_threshold_percent = 90
      ramp_up_minimum_hosts_percent    = 0
      peak_start_time                  = "10:00"
      peak_load_balancing_algorithm    = "DepthFirst"
      ramp_down_start_time             = "16:00"
      ramp_down_load_balancing_algorithm = "DepthFirst"
      ramp_down_capacity_threshold_percent = 90
      ramp_down_force_logoff_users     = true
      ramp_down_minimum_hosts_percent  = 0
      ramp_down_notification_message   = "You will be logged off in 30 min. Make sure to save your work."
      ramp_down_wait_time_minutes      = 30
      ramp_down_stop_hosts_when        = "ZeroActiveSessions"
      off_peak_start_time              = "18:00"
      off_peak_load_balancing_algorithm = "DepthFirst"
    }
  ]

  scaling_plan_schedules = var.avd_host_pool_type == "Pooled" ? local.pooled_scaling_plan_schedules : local.personal_scaling_plan_schedules
  scaling_plan_exclusion_tag = "exclude-${local.scaling_plan_name}"
}

resource "azurerm_virtual_desktop_scaling_plan" "plan" {
  count               = local.scaling_plan_enabled ? 1 : 0
  name                = local.scaling_plan_name
  location            = local.management_plane_location
  resource_group_name = local.use_single_rg ? azurerm_resource_group.rg_single[0].name : azurerm_resource_group.rg_service_objects[0].name
  time_zone           = var.scaling_plan_time_zone
  exclusion_tag       = local.scaling_plan_exclusion_tag
  tags                = local.resource_tags

  dynamic "schedule" {
    for_each = local.scaling_plan_schedules
    content {
      name                             = schedule.value.name
      days_of_week                     = schedule.value.days_of_week
      ramp_up_start_time               = schedule.value.ramp_up_start_time
      ramp_up_load_balancing_algorithm = schedule.value.ramp_up_load_balancing_algorithm
      ramp_up_capacity_threshold_percent = schedule.value.ramp_up_capacity_threshold_percent
      ramp_up_minimum_hosts_percent    = schedule.value.ramp_up_minimum_hosts_percent
      peak_start_time                  = schedule.value.peak_start_time
      peak_load_balancing_algorithm    = schedule.value.peak_load_balancing_algorithm
      ramp_down_start_time             = schedule.value.ramp_down_start_time
      ramp_down_load_balancing_algorithm = schedule.value.ramp_down_load_balancing_algorithm
      ramp_down_capacity_threshold_percent = schedule.value.ramp_down_capacity_threshold_percent
      ramp_down_force_logoff_users     = schedule.value.ramp_down_force_logoff_users
      ramp_down_minimum_hosts_percent  = schedule.value.ramp_down_minimum_hosts_percent
      ramp_down_notification_message   = schedule.value.ramp_down_notification_message
      ramp_down_wait_time_minutes      = schedule.value.ramp_down_wait_time_minutes
      ramp_down_stop_hosts_when        = schedule.value.ramp_down_stop_hosts_when
      off_peak_start_time              = schedule.value.off_peak_start_time
      off_peak_load_balancing_algorithm = schedule.value.off_peak_load_balancing_algorithm
    }
  }

  depends_on = [azurerm_virtual_desktop_host_pool.hostpool]
}

resource "azurerm_virtual_desktop_scaling_plan_host_pool_association" "association" {
  count               = local.scaling_plan_enabled ? 1 : 0
  scaling_plan_id     = azurerm_virtual_desktop_scaling_plan.plan[0].id
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  enabled             = true
  depends_on          = [azurerm_virtual_desktop_host_pool.hostpool]
}
