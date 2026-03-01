# AVD2 Terraform Baseline (Accelerator-Aligned)

This folder provides a Terraform baseline that mirrors the input options from the AVD Accelerator `deploy-baseline.bicep`. It is intended as a starting point so you can control naming, locations, and feature flags, then extend modules as needed. You can deploy using the Accelerator default of multiple resource groups or opt into a single resource group for all resources.

## What is implemented
- Core resource groups (service objects, compute, plus optional network/storage/monitoring RGs).
- Networking: VNET, subnets, NSGs, route tables, ASG, peering, private DNS zones.
- Key Vaults, storage accounts, file shares, and private endpoints.
- AVD host pool, primary application group, workspace, and association.
- Session host NICs/VMs, AVD registration extension, and optional domain join.
- Log Analytics workspace and diagnostic settings.
- Scaling plan with pooled/personal schedule defaults and host pool association.
- Accelerator-style naming defaults with custom naming overrides.
- Tag model aligned to Accelerator inputs.
- Optional single resource group deployment.

## What is scaffolded (variables present; resources to add)
- AVD private link endpoints (connection/discovery/workspace).
- Identity and role assignments for RBAC/AVD groups.
- Management VM for storage domain join.
- GPU/Defender policy assignments.

## Identity provider options

This baseline supports **four identity provider methods** for AVD authentication and session host configuration. The identity provider determines how users authenticate and whether session hosts join a domain.

### Available identity providers

| Provider | File | Domain Join | Use Case |
|----------|------|-------------|----------|
| **EntraID** | `terraform.entraid.tfvars` | ❌ No | Cloud-native organizations without Active Directory |
| **ADDS** | `terraform.adds.tfvars` | ✅ Yes | Hybrid environments with on-premises Active Directory |
| **EntraDS** | `terraform.entrads.tfvars` | ✅ Yes | Azure AD Domain Services (managed AD in Azure) |
| **EntraID Kerberos** | `terraform.entraid-kerberos.tfvars` | ❌ No | Cloud-only with Kerberos auth to Azure Files |

### EntraID (Cloud-Only)
**File:** `terraform.entraid.tfvars`

**Use case:** Cloud-native organizations without on-premises Active Directory infrastructure.

**Authentication:** Microsoft Entra ID (Azure AD)

**Domain join:** Disabled - session hosts do not join a domain

**Configuration:** Ready to use as-is. No domain credentials required.

**Deploy:**
```powershell
terraform plan -var-file="terraform.entraid.tfvars"
terraform apply -var-file="terraform.entraid.tfvars"
```

### ADDS (Active Directory Domain Services)
**File:** `terraform.adds.tfvars`

**Use case:** Hybrid environments with existing on-premises Windows Server Active Directory.

**Authentication:** Windows Server Active Directory Domain Services

**Domain join:** Enabled - session hosts join your on-premises AD domain

**Requirements:**
- Network connectivity to domain controllers (VPN/ExpressRoute/Site-to-Site VPN)
- Domain admin credentials with rights to join computers to the domain
- DNS configured to resolve domain controller addresses

**Configuration required:**
```hcl
identity_domain_name           = "contoso.com"                # Your AD domain FQDN
avd_domain_join_user_name      = "domainadmin@contoso.com"    # Domain join account UPN
avd_domain_join_user_password  = "YourSecurePassword123!"     # Domain join password
avd_ou_path                    = "OU=AVD,OU=Computers,DC=contoso,DC=com"  # Optional
```

**Deploy:**
```powershell
# Edit file first to add domain credentials
notepad terraform.adds.tfvars
terraform plan -var-file="terraform.adds.tfvars"
terraform apply -var-file="terraform.adds.tfvars"
```

### EntraDS (Azure AD Domain Services)
**File:** `terraform.entrads.tfvars`

**Use case:** Organizations wanting managed Active Directory in Azure without on-premises infrastructure.

**Authentication:** Azure AD Domain Services (Microsoft Entra Domain Services)

**Domain join:** Enabled - session hosts join the Azure AD DS managed domain

**Requirements:**
- Azure AD Domain Services deployed and configured in your tenant
- VNet peering configured between AVD VNet and Azure AD DS VNet
- DNS servers configured to point to Azure AD DS domain controllers

**Configuration required:**
```hcl
identity_domain_name           = "contoso.onmicrosoft.com"           # Azure AD DS domain
avd_domain_join_user_name      = "adadmin@contoso.onmicrosoft.com"  # Azure AD DS admin
avd_domain_join_user_password  = "YourSecurePassword123!"           # Admin password
avd_ou_path                    = "OU=AADDC Computers,DC=contoso,DC=onmicrosoft,DC=com"
```

**Deploy:**
```powershell
# Edit file first to add Azure AD DS credentials
notepad terraform.entrads.tfvars
terraform plan -var-file="terraform.entrads.tfvars"
terraform apply -var-file="terraform.entrads.tfvars"
```

### EntraID with Kerberos
**File:** `terraform.entraid-kerberos.tfvars`

**Use case:** Cloud-only deployment with Kerberos authentication support for Azure Files (FSLogix profiles).

**Authentication:** Microsoft Entra ID with Kerberos ticket support

**Domain join:** Disabled - session hosts do not join a domain

**Requirements:**
- Azure Files configured with Azure AD Kerberos authentication enabled

**Configuration required:**
```hcl
identity_domain_name           = "contoso.onmicrosoft.com"    # Your Azure AD tenant domain
```

**Deploy:**
```powershell
# Edit file first to set your tenant domain
notepad terraform.entraid-kerberos.tfvars
terraform plan -var-file="terraform.entraid-kerberos.tfvars"
terraform apply -var-file="terraform.entraid-kerberos.tfvars"
```

### How identity provider selection works

The `avd_identity_service_provider` variable controls the deployment behavior through conditional logic in [main.tf](main.tf):

```terraform
locals {
  enable_domain_join = contains(["ADDS", "EntraDS"], var.avd_identity_service_provider)
}
```

When `avd_identity_service_provider` is set to **ADDS** or **EntraDS**, the domain join extension is created and session hosts join the specified domain. For **EntraID** or **EntraIDKerberos**, the domain join extension is not created, and session hosts authenticate through Microsoft Entra ID only.

## Deployment modes

### Option A: Accelerator default (multiple resource groups)
1. Choose an identity provider and use the corresponding tfvars file (e.g., `terraform.entraid.tfvars`).
2. If using ADDS, EntraDS, or EntraID Kerberos, edit the file and update domain credentials.
3. Keep `use_single_resource_group = false` (default).
4. Optionally override RG names using the `avd_*_rg_custom_name` variables.
5. Run `terraform init`.
6. Run `terraform plan -var-file=terraform.entraid.tfvars` (or your chosen identity file).
7. Run `terraform apply -var-file=terraform.entraid.tfvars` (or your chosen identity file).

### Option B: Single resource group
1. Choose an identity provider and use the corresponding tfvars file (e.g., `terraform.entraid.tfvars`).
2. If using ADDS, EntraDS, or EntraID Kerberos, edit the file and update domain credentials.
3. Set `use_single_resource_group = true`.
4. Optionally set `single_resource_group_name` (otherwise a default name is generated).
5. Run `terraform init`.
6. Run `terraform plan -var-file=terraform.entraid.tfvars` (or your chosen identity file).
7. Run `terraform apply -var-file=terraform.entraid.tfvars` (or your chosen identity file).

## Quick start

### For cloud-only deployment (EntraID - recommended for getting started)
1. Run `terraform init` to initialize the working directory.
2. Run `terraform plan -var-file="terraform.entraid.tfvars"` to preview changes.
3. Run `terraform apply -var-file="terraform.entraid.tfvars"` to deploy.

### For domain-joined deployment (ADDS or EntraDS)
1. Edit the appropriate tfvars file (`terraform.adds.tfvars` or `terraform.entrads.tfvars`).
2. Update domain credentials and connection information.
3. Run `terraform init` to initialize the working directory.
4. Run `terraform plan -var-file="terraform.adds.tfvars"` to preview changes.
5. Run `terraform apply -var-file="terraform.adds.tfvars"` to deploy.

### For custom configuration
1. Copy [terraform.tfvars.example](terraform.tfvars.example) to `terraform.tfvars`.
2. Set required values (locations, credentials, network settings, identity provider).
3. Run `terraform init`, `terraform plan -var-file=terraform.tfvars`, then `terraform apply -var-file=terraform.tfvars`.

## PowerShell command walkthrough
Run these from the AVD2 folder:
- `Set-Location .\Azure_AVD_Accelerator_PowerShell\Terraform\AVD2`

### 1) Initialize the working directory
Why: Downloads provider plugins and configures backend/state so Terraform can plan/apply safely.

- `terraform init`

Use an identity-specific configuration file:

- `terraform plan -var-file=terraform.entraid.tfvars`
- `terraform plan -var-file=terraform.adds.tfvars`
- `terraform plan -var-file=terraform.entrads.tfvars`
- `terraform plan -var-file=terraform.entraid-kerberos.tfvars`

Or use an environment-specific file:

- `terraform plan -var-file=terraform.dev.tfvars`
- `terraform plan -var-file=terraform.test.tfvars`
- `terraform plan -var-file=terraform.prod.tfvars`

Or use a custom configuration:

- `terraform plan -var-file=terraform.tfvars`

### 5) Apply (execute changes)
Why: Creates or updates Azure resources based on the plan.

Apply with an identity-specific configuration:

- `terraform apply -var-file=terraform.entraid.tfvars`
- `terraform apply -var-file=terraform.adds.tfvars`
- `terraform apply -var-file=terraform.entrads.tfvars`
- `terraform apply -var-file=terraform.entraid-kerberos.tfvars`

Apply with an environment-specific file:

- `terraform apply -var-file=terraform.dev.tfvars`
- `terraform apply -var-file=terraform.test.tfvars`
- `terraform apply -var-file=terraform.prod.tfvars`

Apply with a custom configuration:

- `terraform apply -var-file=terraformfvars`
- `terraform plan -var-file=terraform.test.tfvars`
- `terraform plan -var-file=terraform.prod.tfvars`

### 5) Apply (execute changes)
Why: Creates or updates Azure resources based on the plan.

- `terraform apply -var-file=terraform.tfvars`

Apply with a specific environment file:

- `terraform apply -var-file=terraform.dev.tfvars`
- `terraform apply -var-file=terraform.test.tfvars`
- `terraform apply -var-file=terraform.prod.tfvars`

Auto-approve (use with caution):

- `terraform apply -auto-approve -var-file=terraform.tfvars`

### 6) Targeted apply (advanced, use sparingly)
Why: Helpful when unblocking a dependency or remediating a single resource, but can lead to drift if overused.

- `terraform apply -var-file=terraform.tfvars -target=azurerm_key_vault.workload`

### 7) Refresh state (optional)
Why: Reconcile local state with real Azure resources.
**Identity provider files:** Four pre-configured tfvars files are provided for different identity scenarios. Use `terraform.entraid.tfvars` for cloud-only deployments (no configuration needed), or edit `terraform.adds.tfvars` / `terraform.entrads.tfvars` with your domain credentials before using.
- **Domain join behavior:** Session hosts automatically join a domain when `avd_identity_service_provider` is set to `ADDS` or `EntraDS`. For `EntraID` or `EntraIDKerberos`, no domain join occurs.
- **Networking requirements:** ADDS deployments require VPN/ExpressRoute connectivity to on-premises domain controllers. EntraDS deployments require VNet peering to Azure AD DS VNet and proper DNS configuration.
- 
- `terraform refresh -var-file=terraform.tfvars`

### 8) Show current state (optional)
Why: Inspect deployed resources tracked by Terraform.

- `terraform show`

### 9) Destroy (tear down resources)
Why: Clean up the environment when you are finished.

- `terraform destroy -var-file=terraform.tfvars`

## Choosing a deployment method
- Multi-RG (Accelerator default): leave `use_single_resource_group = false` or omit it.
- Single-RG: set `use_single_resource_group = true` and optionally `single_resource_group_name`.

## Notes
- `avd_workload_subscription_id` is kept as an input to mirror the Accelerator but the provider uses `subscription_id`. Use provider aliases if you need multi-subscription deployments.
- If `existing_vnet_avd_subnet_resource_id` is set, it takes precedence over `vnet_name`/`subnet_name` lookup.

## File synopsis
- [main.tf](main.tf): Resource groups, AVD host pool/app group/workspace, session hosts, extensions.
- [networking.tf](networking.tf): VNET, subnets, NSGs, route tables, ASG, peering, private DNS.
- [storage.tf](storage.tf): Key Vaults, storage accounts/shares, private endpoints, disk encryption set.
- [monitoring.tf](monitoring.tf): Log Analytics and diagnostic settings.
- [scaling.tf](scaling.tf): Scaling plan schedules and association.
- [locals.accelerator.tf](locals.accelerator.tf): Naming, tags, derived values.
- [variables.accelerator.tf](variables.accelerator.tf): Accelerator-aligned inputs.
- [outputs.tf](outputs.tf): Key output values for integration.
