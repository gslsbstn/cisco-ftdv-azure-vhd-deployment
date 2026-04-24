# Cisco FTDv on Azure from Azure Compute Gallery

This repository deploys one Cisco Secure Firewall Threat Defense Virtual (FTDv) instance on Azure by using an existing Azure Compute Gallery image version.

Terraform does not download, upload or import the Cisco VHD. Image preparation is an explicit prerequisite. By the time Terraform runs, the FTDv VHD must already be available as an Azure Compute Gallery image version that the deployment identity can read.

## What This Repository Creates

- one dedicated deployment resource group
- one subnet in an existing VNet, or reuse of an existing subnet
- four NICs for management, diagnostic, outside and inside
- one management network security group
- optional public IP and DNS label for the management interface
- one Cisco FTDv VM created from an Azure Compute Gallery image version

## What This Repository Does Not Do

- it does not accept Azure Marketplace terms
- it does not create or manage Cisco licensing
- it does not download the Cisco FTDv VHD
- it does not upload the VHD to Azure Storage
- it does not create the Azure Compute Gallery image definition or image version
- it does not inject production day-0 bootstrap data
- it does not create the target VNet

## Azure Prerequisites

Before running Terraform, prepare the following.

### Azure Access

You need an Azure identity that can:

- read the target VNet and subnet
- create a subnet if `create_subnet = true`
- create resource groups, NICs, NSGs, public IPs, managed disks and VMs
- read the Azure Compute Gallery image version

For a simple single-subscription setup, `Contributor` on the deployment subscription plus read access to the image gallery is usually sufficient. In stricter environments, grant only the required scoped permissions.

### Cisco FTDv VHD

You need a Cisco FTDv VHD image that you are licensed and entitled to use. Obtain it from Cisco according to your Cisco account, support contract and licensing model.

Do not commit VHD files, license keys, registration keys or bootstrap secrets to this repository.

### Azure Compute Gallery Image

Terraform expects a full Azure Compute Gallery image version resource ID, for example:

```text
/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ftdv-images-example/providers/Microsoft.Compute/galleries/acgNetworkAppliances/images/ftdv-byol-7-7-0/versions/1.0.0
```

The gallery image version may be in the same resource group as the deployment, a different resource group, or a different subscription if access is granted.

A typical manual image-preparation flow is:

1. Download the Cisco FTDv VHD from Cisco.
2. Upload the VHD to Azure as a managed disk by direct upload.
3. Create an Azure Compute Gallery if you do not already have one.
4. Create a gallery image definition for Cisco FTDv.
5. Create a gallery image version from the managed disk.
6. Grant the Terraform identity read access to the image version.

Use image definition metadata that matches the Cisco image you are publishing, such as publisher, offer, SKU, OS type and Hyper-V generation. Keep version numbers immutable and publish a new gallery image version when you change the base image.

### Network

You need an existing Azure VNet. This module can either:

- create the FTDv subnet inside that VNet with `create_subnet = true`
- reuse an existing subnet with `create_subnet = false`

The example CIDR values use documentation-only address ranges:

- private example subnet: `10.0.10.0/28`
- public documentation source IP: `203.0.113.10/32`

Replace them with your real network design before applying.

## Repository Layout

```text
.
├── .gitignore
├── README.md
├── main.tf
├── outputs.tf
├── provider.tf
├── terraform.tfvars.example
├── variables.tf
├── versions.tf
└── scripts
    ├── bootstrap-example.txt
    └── setup-local-env.sh
```

## Required Inputs

At minimum, provide:

- `deployment_resource_group_name`
- `network_resource_group_name`
- `virtual_network_name`
- `subnet_name`
- `create_subnet`
- `expected_subnet_cidr`
- `ftd_vm_name`
- `gallery_image_version_id`
- `management_allowed_cidrs`

Common optional inputs:

- `location`
- `availability_zone`
- `vm_size`
- `enable_management_public_ip`
- `management_public_ip_dns_label`
- static private IPs for the four NICs
- `enable_accelerated_networking`
- `os_disk_storage_account_type`
- `tags`

## Local Usage

### 1. Install Tools

Install:

- Terraform `>= 1.6`
- Azure CLI

### 2. Log In To Azure

```bash
az login
az account set --subscription "00000000-0000-0000-0000-000000000000"
```

Export the Azure subscription and tenant IDs used by the AzureRM provider:

```bash
export ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
export ARM_TENANT_ID="11111111-1111-1111-1111-111111111111"
```

### 3. Create Local Environment Variables

For local use, you can generate `.env.local`:

```bash
bash scripts/setup-local-env.sh
source .env.local
```

The helper writes local Azure environment variables. `.env.local` is ignored by git.

### 4. Create `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Azure values:

```hcl
deployment_resource_group_name = "rg-cisco-ftdv-example"
network_resource_group_name    = "rg-network-example"
virtual_network_name           = "vnet-example"
subnet_name                    = "snet-ftdv"
create_subnet                  = true
expected_subnet_cidr           = "10.0.10.0/28"

ftd_vm_name                    = "ftdv01"
location                       = "westeurope"
availability_zone              = "1"
vm_size                        = "Standard_D8s_v3"
gallery_image_version_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ftdv-images-example/providers/Microsoft.Compute/galleries/acgNetworkAppliances/images/ftdv-byol-7-7-0/versions/1.0.0"

management_allowed_cidrs       = ["203.0.113.10/32"]
enable_management_public_ip    = true
management_public_ip_dns_label = "ftdv01-example"
```

If your Azure policy or network design blocks public management access:

```hcl
enable_management_public_ip = false
```

## Terraform State

By default this repository uses Terraform local state. That keeps the public example simple and avoids baking in an organization-specific backend.

Initialize locally with:

```bash
terraform init
```

For team usage, add your preferred backend before applying. Common choices are Azure Storage, Terraform Cloud or another backend supported by Terraform.

Do not commit state files or backend credentials. `.gitignore` excludes local Terraform state files.

## Plan And Apply

Format and validate:

```bash
terraform fmt -check -diff -recursive
terraform validate
```

Review the plan:

```bash
terraform plan
```

Apply after reviewing the resources:

```bash
terraform apply
```

## Day-0 Bootstrap

[`scripts/bootstrap-example.txt`](scripts/bootstrap-example.txt) is only a placeholder. Do not commit real bootstrap data, registration keys, passwords, tokens or FMC onboarding secrets.

If you add bootstrap support later, pass sensitive content through a secret store, CI/CD secret variable or another secure runtime mechanism.

## Outputs

The deployment exports:

- deployment resource group name
- FTDv VM resource ID
- operating system disk resource ID
- gallery image version resource ID
- management public IP and FQDN if enabled
- private IPs for management, diagnostic, outside and inside
