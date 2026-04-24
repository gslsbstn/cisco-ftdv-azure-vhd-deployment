variable "deployment_resource_group_name" {
  description = "Name of the dedicated resource group that Terraform creates for the FTDv deployment resources."
  type        = string
}

variable "network_resource_group_name" {
  description = "Name of the existing resource group that already contains the target virtual network and subnet."
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the existing virtual network that contains the target subnet."
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet used for the FTDv NICs. It is created in the existing VNet when create_subnet is true."
  type        = string
}

variable "create_subnet" {
  description = "Create the subnet inside the existing VNet. Set to false if the subnet already exists and should only be looked up."
  type        = bool
  default     = true
}

variable "expected_subnet_cidr" {
  description = "CIDR used when creating the subnet and the expected CIDR when an existing subnet is looked up."
  type        = string
  default     = "10.0.10.0/28"

  validation {
    condition     = can(cidrhost(var.expected_subnet_cidr, 0))
    error_message = "expected_subnet_cidr must be a valid IPv4 CIDR."
  }
}

variable "location" {
  description = "Azure region for the deployment resource group and compute resources. Leave null to reuse the existing VNet location."
  type        = string
  default     = null
  nullable    = true
}

variable "availability_zone" {
  description = "Optional availability zone for the public IP and virtual machine, for example 1, 2 or 3."
  type        = string
  default     = null
  nullable    = true
}

variable "ftd_vm_name" {
  description = "Name of the Cisco FTDv virtual machine."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size for the FTDv instance."
  type        = string
  default     = "Standard_D8s_v3"
}

variable "gallery_image_version_id" {
  description = "Resource ID of the existing Azure Compute Gallery image version used to create the Cisco FTDv VM."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourcegroups/.+/providers/microsoft\\.compute/galleries/.+/images/.+/versions/.+$", lower(var.gallery_image_version_id)))
    error_message = "gallery_image_version_id must be a valid Azure Compute Gallery image version resource ID."
  }
}

variable "management_allowed_cidrs" {
  description = "CIDR list that is allowed to access the public management interface over the ports enabled below."
  type        = list(string)

  validation {
    condition = length(var.management_allowed_cidrs) > 0 && alltrue([
      for cidr in var.management_allowed_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "management_allowed_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "allow_ssh_to_management" {
  description = "Whether inbound SSH should be allowed on the public management IP."
  type        = bool
  default     = true
}

variable "allow_https_to_management" {
  description = "Whether inbound HTTPS should be allowed on the public management IP."
  type        = bool
  default     = true
}

variable "management_public_ip_dns_label" {
  description = "Optional DNS label for the public management IP. Must be globally unique in the Azure region if set."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_management_public_ip" {
  description = "Create and attach a public IP to the management NIC. Set to false if Azure Policy or your network design requires private-only management."
  type        = bool
  default     = true
}

variable "management_private_ip" {
  description = "Optional static private IP for the management NIC."
  type        = string
  default     = null
  nullable    = true
}

variable "diagnostic_private_ip" {
  description = "Optional static private IP for the diagnostic NIC."
  type        = string
  default     = null
  nullable    = true
}

variable "outside_private_ip" {
  description = "Optional static private IP for the outside NIC."
  type        = string
  default     = null
  nullable    = true
}

variable "inside_private_ip" {
  description = "Optional static private IP for the inside NIC."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_accelerated_networking" {
  description = "Enable accelerated networking on all NICs. Only use this with VM sizes that support it."
  type        = bool
  default     = true
}

variable "os_disk_storage_account_type" {
  description = "Storage SKU for the operating system managed disk created from the gallery image version."
  type        = string
  default     = "Premium_LRS"
}

variable "tags" {
  description = "Optional Azure tags applied to all created resources."
  type        = map(string)
  default     = {}
}
