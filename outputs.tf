data "azurerm_client_config" "current" {}

output "deployment_resource_group_name" {
  description = "Name of the dedicated resource group created for the FTDv deployment."
  value       = azurerm_resource_group.deployment.name
}

output "ftdv_vm_id" {
  description = "Resource ID of the Cisco FTDv virtual machine."
  value       = azurerm_virtual_machine.ftdv.id
}

output "ftdv_os_disk_id" {
  description = "Resource ID of the operating system managed disk created for the Cisco FTDv virtual machine."
  value       = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.deployment.name}/providers/Microsoft.Compute/disks/${var.ftd_vm_name}-osdisk"
}

output "gallery_image_version_id" {
  description = "Resource ID of the Azure Compute Gallery image version used for the Cisco FTDv virtual machine."
  value       = var.gallery_image_version_id
}

output "management_public_ip_address" {
  description = "Public IP address of the management interface."
  value       = try(azurerm_public_ip.management[0].ip_address, null)
}

output "management_public_fqdn" {
  description = "Optional Azure-generated FQDN of the management public IP."
  value       = try(azurerm_public_ip.management[0].fqdn, null)
}

output "management_private_ip_address" {
  description = "Private IP address of the management NIC."
  value       = azurerm_network_interface.management.private_ip_address
}

output "diagnostic_private_ip_address" {
  description = "Private IP address of the diagnostic NIC."
  value       = azurerm_network_interface.diagnostic.private_ip_address
}

output "outside_private_ip_address" {
  description = "Private IP address of the outside NIC."
  value       = azurerm_network_interface.outside.private_ip_address
}

output "inside_private_ip_address" {
  description = "Private IP address of the inside NIC."
  value       = azurerm_network_interface.inside.private_ip_address
}

output "management_url" {
  description = "Convenience URL for the public management interface if a DNS label is configured."
  value       = try(azurerm_public_ip.management[0].fqdn, null) == null ? null : "https://${azurerm_public_ip.management[0].fqdn}"
}
