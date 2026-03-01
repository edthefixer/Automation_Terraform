# Terraform AVD Deployment Guide

## Prerequisites
- Terraform installed and configured (version 1.1.7 or later)
- Azure CLI installed and authenticated (`az login`)
- Azure subscription with Contributor or Owner role
- For domain-joined scenarios (ADDS, EntraDS, EntraID Kerberos): Network connectivity and credentials

---

## Quick Start (Cloud-Only Deployment)

**Deploy AVD with Entra ID authentication:**

```powershell
# 1. Get your Azure credentials
az account show --query "{subscriptionId:id, tenantId:tenantId}" -o table

# 2. Create terraform.client.tfvars (replace with your IDs from step 1)
@"
subscription_id = "your-subscription-id-here"
tenant_id       = "your-tenant-id-here"
"@ | Out-File -FilePath terraform.client.tfvars -Encoding utf8

# 3. Initialize and deploy
terraform init
terraform plan -var-file="terraform.client.tfvars" -var-file="terraform.test.tfvars" -var-file="terraform.entraid.tfvars"
terraform apply -var-file="terraform.client.tfvars" -var-file="terraform.test.tfvars" -var-file="terraform.entraid.tfvars"
```

✅ Your AVD environment will be deployed with Entra ID authentication.

---

## Azure Subscription & Tenant Information

**Two methods to provide Azure credentials:**

| Feature | Method 1: Client File | Method 2: Environment Variables |
|---------|----------------------|--------------------------------|
| **Setup complexity** | ⭐ Easy (one-time file creation) | ⭐⭐ Medium (set per session) |
| **Best for** | Multi-client scenarios, team sharing | Single user, temporary deployments |
| **Security** | Gitignored file, never committed | Session-only, expires on close |
| **Portability** | ✅ Works across all shells | ❌ Shell-specific syntax |
| **Recommendation** | ✅ **Recommended for most users** | Alternative option |

### METHOD 1: Client Credentials File (Recommended)

Create a `terraform.client.tfvars` file with your Azure credentials:

```powershell
az account show --query "{subscriptionId:id, tenantId:tenantId}" -o table
```

Add your IDs to the file:
```hcl
subscription_id = "your-subscription-id-here"
tenant_id       = "your-tenant-id-here"
```

### METHOD 2: Environment Variables (Alternative)

**PowerShell (Windows):**
```powershell
$env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
$env:ARM_TENANT_ID = "your-tenant-id"
```

**Bash/Linux/macOS:**
```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
```

---

## Notes
- For domain join scenarios, use the appropriate .tfvars file (e.g., terraform.adds.tfvars or terraform.entrads.tfvars) and ensure network connectivity to domain controllers or Azure AD DS.
- For Entra ID (cloud-only), domain join is disabled and no domain join extension is created.
- Adjust variable values in .tfvars files as needed for your environment.
- Always review output and logs for errors or warnings during deployment.

---

## Example Command Order

1. terraform plan -var-file="terraform.client.tfvars" -var-file="terraform.test.tfvars" -var-file="terraform.entraid.tfvars"
2. terraform apply -var-file="terraform.client.tfvars" -var-file="terraform.test.tfvars" -var-file="terraform.entraid.tfvars"

---

For more details, see the official [Azure Virtual Desktop prerequisites](https://learn.microsoft.com/en-us/azure/virtual-desktop/prerequisites?tabs=portal).
