# ============================================================================
# AVD Deployment - EntraID (Cloud-Only) Identity Provider
# ============================================================================
# Use case: Cloud-native organizations without on-premises Active Directory
# Authentication: Microsoft Entra ID (Azure AD)
# Domain join: DISABLED (no domain join extension created)
# ============================================================================

deployment_prefix             = "ETF"  # Updated to reflect the new value
deployment_environment        = "Test"

# ============================================================================
# IDENTITY CONFIGURATION - EntraID (Cloud-Only)
# ============================================================================
avd_identity_service_provider = "EntraID"

# Domain settings: Set to "none" for cloud-only deployment
identity_domain_name           = "contoso.com"
avd_domain_join_user_name      = "domainadmin@contoso.com"
avd_domain_join_user_password  = "YourSecurePassword123!"
avd_ou_path                    = "OU=AVD,OU=Computers,DC=contoso,DC=com"

# ============================================================================
# LOCATION SETTINGS
# ============================================================================
avd_session_host_location     = "East US"
avd_management_plane_location = "East US"
management_plane_location_short = "eus"
session_host_location_short     = "eus"
scaling_plan_time_zone          = "UTC"

# ============================================================================
# SESSION HOST CREDENTIALS
# ============================================================================
avd_vm_local_user_name        = "your-local-admin"
avd_vm_local_user_password    = "your-local-device---password *"

# ============================================================================
# HOST POOL CONFIGURATION
# ============================================================================
avd_host_pool_type            = "Pooled"
host_pool_preferred_app_group_type = "Desktop"
avd_host_pool_load_balancer_type   = "DepthFirst"

# ============================================================================
# SESSION HOST DEPLOYMENT
# ============================================================================
avd_deploy_session_hosts      = true
avd_deploy_session_hosts_count = 1
avd_session_host_count_index  = 1
avd_session_hosts_size        = "Standard_D2als_v6"

# ============================================================================
# NETWORKING (Using Terraform-created VNET)
# ============================================================================
existing_vnet_avd_subnet_resource_id = ""
existing_vnet_private_endpoint_subnet_resource_id = ""
vnet_resource_group           = "rg-network"
vnet_name                     = "vnet-avd"
subnet_name                   = "snet-avd"

# ============================================================================
# STORAGE CONFIGURATION
# ============================================================================
create_avd_fslogix_deployment = true
create_app_attach_deployment  = false

# ============================================================================
# AZURE SUBSCRIPTION & TENANT
# ============================================================================
subscription_id = "bd67233d-38af-45db-a98e-a10a2b443d8d"
tenant_id       = "d3edc3c2-c1ad-469e-a53a-7dac46272775"

# ============================================================================
# TAGS
# ============================================================================
create_resource_tags          = false

tags = {
  Environment = "Test"
  IdentityProvider = "EntraID"
}
