# Creates a Azure Linux Virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  network_interface_ids           = [azurerm_network_interface.nic.id]
  size                            = var.size
  admin_username                  = var.admin_username
  admin_password                  = random_password.password.result
  disable_password_authentication = var.disable_password_authentication
  source_image_id                 = var.source_image_id
  patch_assessment_mode           = var.patch_assessment_mode
  patch_mode                      = var.patch_mode
  secure_boot_enabled             = var.secure_boot_enabled
  vtpm_enabled                    = var.vtpm_enabled

  os_disk {
    name                 = "${var.name}-disk"
    caching              = var.caching
    storage_account_type = var.storage_account_type
    disk_size_gb         = var.disk_size_gb
  }
  depends_on = [
    azurerm_network_interface.nic
  ]
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}

#resource "azurerm_virtual_machine_extension" "example" {
#  name                 = "${var.name}-defender"
#  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
#  publisher            = "Microsoft.Azure.Extensions"
#  type                 = "CustomScript"
#  type_handler_version = "2.0"
#
#  settings = <<SETTINGS
#    {
#      "fileUris": ["https://sharedsaelk.blob.core.windows.net/s1-data/install_linux_defender.sh"],
#      "commandToExecute": "sh install_linux_defender.sh"
#    }
#SETTINGS
#}

# Creates Network Interface Card with private IP for Virtual Machine
resource "azurerm_network_interface" "nic" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name                          = var.ip_name
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = var.private_ip_address_allocation
  }
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}


# Creates Network Security Group NSG for Virtual Machine
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.name}-nsg"
  location            = azurerm_linux_virtual_machine.vm.location
  resource_group_name = azurerm_linux_virtual_machine.vm.resource_group_name
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }

}


# Creates Network Security Group Default Rules for Virtual Machine
resource "azurerm_network_security_rule" "nsg_rules" {
  for_each                    = var.nsg_rules
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_address_prefixes     = each.value.source_address_prefixes
  source_port_range           = each.value.source_port_range
  destination_address_prefix  = each.value.destination_address_prefix
  destination_port_range      = each.value.destination_port_range
  network_security_group_name = azurerm_network_security_group.nsg.name
  resource_group_name         = azurerm_linux_virtual_machine.vm.resource_group_name
}


# Creates association (i.e) adds NSG to the NIC
resource "azurerm_network_interface_security_group_association" "security_group_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}




#Creates a Public IP for load balancer
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.name}-public-ip"
  resource_group_name = azurerm_linux_virtual_machine.vm.resource_group_name
  location            = azurerm_linux_virtual_machine.vm.location
  ip_version          = var.ip_version
  sku                 = var.public_ip_sku
  sku_tier            = var.public_ip_sku_tier
  allocation_method   = var.allocation_method
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}


#Creates a Load balancer
resource "azurerm_lb" "lb" {
  name                = "${var.name}-lb"
  resource_group_name = azurerm_linux_virtual_machine.vm.resource_group_name
  location            = azurerm_linux_virtual_machine.vm.location
  sku                 = var.lb_sku
  sku_tier            = var.lb_sku_tier
  frontend_ip_configuration {
    name                 = "${var.name}-pubIP"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
  lifecycle {
    ignore_changes = [
      tags,
    ]
  }
}


# Creates Backenf address pool for LB
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name            = "${var.name}-backend_pool"
  loadbalancer_id = azurerm_lb.lb.id
  depends_on = [
    azurerm_lb.lb
  ]
}


# Creates association between LB and vm 
resource "azurerm_network_interface_backend_address_pool_association" "backend_association" {
  network_interface_id    = azurerm_network_interface.nic.id
  ip_configuration_name   = var.ip_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.backend_pool.id
  depends_on = [
    azurerm_network_interface.nic,
    azurerm_lb_backend_address_pool.backend_pool
  ]
}


# Creates a load balancer probe
resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "https"
  port            = var.probe_ports

}


# Creates a Load balancer rule with deafult rules
resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "htpps"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "${var.name}-pubIP"
  probe_id                       = azurerm_lb_probe.lb_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.backend_pool.id]
}




# Getting existing Keyvault name to store credentials as secrets
data "azurerm_key_vault" "key_vault" {
  # Skipped when the caller supplies key_vault_id instead of a name (it then
  # omits keyvault_name, which defaults to ""). Gated on keyvault_name, NOT
  # key_vault_id: only the former is known at plan.
  count = var.keyvault_name == "" ? 0 : 1

  name                = var.keyvault_name
  resource_group_name = var.resource_group_name
}

locals {
  # Prefer the id the caller wired (a computed attribute, so unknown at plan —
  # which is exactly what defers the key-vault secret below to apply). Fall back
  # to the by-name lookup for callers that still pass only keyvault_name.
  key_vault_id = var.key_vault_id != null ? var.key_vault_id : one(data.azurerm_key_vault.key_vault[*].id)
}

# Creates a random string password for vm default user
resource "random_password" "password" {
  length      = 12
  lower       = true
  min_lower   = 6
  min_numeric = 2
  min_special = 2
  min_upper   = 2
  numeric     = true
  special     = true
  upper       = true

}
# Creates a secret to store DB credentials 
resource "azurerm_key_vault_secret" "vm_password" {
  name         = "${var.name}-vmpwd"
  value        = random_password.password.result
  key_vault_id = local.key_vault_id
  depends_on   = [azurerm_linux_virtual_machine.vm]
}

# --- Added from old repo (missing in new as of comparison) ---
data "azurerm_recovery_services_vault" "services_vault" {
  count               = lower(var.environment) == "prod" ? 0 : 1
  name                = var.recovery_services_vault_name
  resource_group_name = var.services_vault_resource_group_name
}


# --- Added from old repo (missing in new as of comparison) ---
data "azurerm_backup_policy_vm" "policy" {
  count               = lower(var.environment) == "prod" ? 0 : 1
  name                = "EnhancedPolicy"
  recovery_vault_name = data.azurerm_recovery_services_vault.services_vault[0].name
  resource_group_name = data.azurerm_recovery_services_vault.services_vault[0].resource_group_name
}

# --- Added from old repo (missing in new as of comparison) ---
resource "azurerm_backup_protected_vm" "backup_protected_vm" {
  count               = lower(var.environment) == "prod" ? 0 : 1
  resource_group_name = data.azurerm_recovery_services_vault.services_vault[0].resource_group_name
  recovery_vault_name = data.azurerm_recovery_services_vault.services_vault[0].name
  source_vm_id        = azurerm_linux_virtual_machine.vm.id
  backup_policy_id    = data.azurerm_backup_policy_vm.policy[0].id

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}