output "vmss_id" {
  value       = module.service.vmss_id
  description = "ID of the VM scale-set"
}

output "nsg_id" {
  value       = azurerm_network_security_group.nsg.id
  description = "ID of the network security group attached to the Collector Server nodes"
}
