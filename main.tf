locals {
  deployment_location = coalesce(var.location, data.azurerm_virtual_network.target.location)

  common_tags = merge(
    {
      managed_by = "terraform"
      workload   = "cisco-ftdv"
    },
    var.tags
  )

  management_security_rules = merge(
    var.allow_ssh_to_management ? {
      ssh = {
        name     = "Allow-SSH-Management"
        priority = 100
        port     = "22"
      }
    } : {},
    var.allow_https_to_management ? {
      https = {
        name     = "Allow-HTTPS-Management"
        priority = 110
        port     = "443"
      }
    } : {}
  )

  target_subnet_id = var.create_subnet ? azurerm_subnet.target[0].id : data.azurerm_subnet.target[0].id
}

data "azurerm_virtual_network" "target" {
  name                = var.virtual_network_name
  resource_group_name = var.network_resource_group_name
}

data "azurerm_subnet" "target" {
  count = var.create_subnet ? 0 : 1

  name                 = var.subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

resource "azurerm_subnet" "target" {
  count = var.create_subnet ? 1 : 0

  name                 = var.subnet_name
  resource_group_name  = var.network_resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = [var.expected_subnet_cidr]
}

resource "azurerm_resource_group" "deployment" {
  name     = var.deployment_resource_group_name
  location = local.deployment_location
  tags     = local.common_tags

  lifecycle {
    precondition {
      condition = var.create_subnet ? true : contains(
        data.azurerm_subnet.target[0].address_prefixes,
        var.expected_subnet_cidr
      )
      error_message = "The looked up subnet does not expose the expected CIDR. Update expected_subnet_cidr or check the target subnet."
    }
  }
}

resource "azurerm_public_ip" "management" {
  count = var.enable_management_public_ip ? 1 : 0

  name                = "${var.ftd_vm_name}-mgmt-pip"
  location            = azurerm_resource_group.deployment.location
  resource_group_name = azurerm_resource_group.deployment.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.management_public_ip_dns_label
  zones               = var.availability_zone == null ? null : [var.availability_zone]
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "management" {
  name                = "${var.ftd_vm_name}-mgmt-nsg"
  location            = azurerm_resource_group.deployment.location
  resource_group_name = azurerm_resource_group.deployment.name
  tags                = local.common_tags
}

resource "azurerm_network_security_rule" "management_inbound" {
  for_each = local.management_security_rules

  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefixes     = var.management_allowed_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.deployment.name
  network_security_group_name = azurerm_network_security_group.management.name
}

resource "azurerm_network_interface" "management" {
  name                           = "${var.ftd_vm_name}-nic0-mgmt"
  location                       = azurerm_resource_group.deployment.location
  resource_group_name            = azurerm_resource_group.deployment.name
  accelerated_networking_enabled = var.enable_accelerated_networking
  tags                           = local.common_tags

  ip_configuration {
    name                          = "management"
    subnet_id                     = local.target_subnet_id
    private_ip_address_allocation = var.management_private_ip == null ? "Dynamic" : "Static"
    private_ip_address            = var.management_private_ip
    public_ip_address_id          = var.enable_management_public_ip ? azurerm_public_ip.management[0].id : null
  }
}

resource "azurerm_network_interface" "diagnostic" {
  name                           = "${var.ftd_vm_name}-nic1-diagnostic"
  location                       = azurerm_resource_group.deployment.location
  resource_group_name            = azurerm_resource_group.deployment.name
  accelerated_networking_enabled = var.enable_accelerated_networking
  tags                           = local.common_tags

  ip_configuration {
    name                          = "diagnostic"
    subnet_id                     = local.target_subnet_id
    private_ip_address_allocation = var.diagnostic_private_ip == null ? "Dynamic" : "Static"
    private_ip_address            = var.diagnostic_private_ip
  }
}

resource "azurerm_network_interface" "outside" {
  name                           = "${var.ftd_vm_name}-nic2-outside"
  location                       = azurerm_resource_group.deployment.location
  resource_group_name            = azurerm_resource_group.deployment.name
  accelerated_networking_enabled = var.enable_accelerated_networking
  ip_forwarding_enabled          = true
  tags                           = local.common_tags

  ip_configuration {
    name                          = "outside"
    subnet_id                     = local.target_subnet_id
    private_ip_address_allocation = var.outside_private_ip == null ? "Dynamic" : "Static"
    private_ip_address            = var.outside_private_ip
  }
}

resource "azurerm_network_interface" "inside" {
  name                           = "${var.ftd_vm_name}-nic3-inside"
  location                       = azurerm_resource_group.deployment.location
  resource_group_name            = azurerm_resource_group.deployment.name
  accelerated_networking_enabled = var.enable_accelerated_networking
  ip_forwarding_enabled          = true
  tags                           = local.common_tags

  ip_configuration {
    name                          = "inside"
    subnet_id                     = local.target_subnet_id
    private_ip_address_allocation = var.inside_private_ip == null ? "Dynamic" : "Static"
    private_ip_address            = var.inside_private_ip
  }
}

resource "azurerm_network_interface_security_group_association" "management" {
  network_interface_id      = azurerm_network_interface.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_virtual_machine" "ftdv" {
  name                         = var.ftd_vm_name
  resource_group_name          = azurerm_resource_group.deployment.name
  location                     = azurerm_resource_group.deployment.location
  vm_size                      = var.vm_size
  primary_network_interface_id = azurerm_network_interface.management.id
  network_interface_ids = [
    azurerm_network_interface.management.id,
    azurerm_network_interface.diagnostic.id,
    azurerm_network_interface.outside.id,
    azurerm_network_interface.inside.id,
  ]
  delete_os_disk_on_termination = true
  zones                         = var.availability_zone == null ? null : [var.availability_zone]
  tags                          = local.common_tags

  storage_image_reference {
    id = var.gallery_image_version_id
  }

  storage_os_disk {
    name              = "${var.ftd_vm_name}-osdisk"
    create_option     = "FromImage"
    os_type           = "Linux"
    caching           = "ReadWrite"
    managed_disk_type = var.os_disk_storage_account_type
  }

  depends_on = [
    azurerm_network_interface_security_group_association.management,
  ]
}
