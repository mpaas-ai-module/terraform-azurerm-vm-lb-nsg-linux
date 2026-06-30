# Auto-generated producer outputs for DAG wiring (mpaas-ai-module migration).
# Exposes id / name / connection attributes other resources consume.

output "vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}
output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}
output "vm_private_ip_address" {
  value = azurerm_linux_virtual_machine.vm.private_ip_address
}
output "nic_id" {
  value = azurerm_network_interface.nic.id
}
output "nic_name" {
  value = azurerm_network_interface.nic.name
}
output "nic_private_ip_address" {
  value = azurerm_network_interface.nic.private_ip_address
}
output "nsg_id" {
  value = azurerm_network_security_group.nsg.id
}
output "nsg_name" {
  value = azurerm_network_security_group.nsg.name
}
output "public_ip_id" {
  value = azurerm_public_ip.public_ip.id
}
output "public_ip_name" {
  value = azurerm_public_ip.public_ip.name
}
output "public_ip_ip_address" {
  value = azurerm_public_ip.public_ip.ip_address
}
output "public_ip_fqdn" {
  value = azurerm_public_ip.public_ip.fqdn
}
output "lb_id" {
  value = azurerm_lb.lb.id
}
output "lb_name" {
  value = azurerm_lb.lb.name
}
output "backend_pool_id" {
  value = azurerm_lb_backend_address_pool.backend_pool.id
}
output "backend_pool_name" {
  value = azurerm_lb_backend_address_pool.backend_pool.name
}
