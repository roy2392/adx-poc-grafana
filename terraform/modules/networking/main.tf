# ==============================================================================
# Virtual Network
# ==============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-adx-poc"
  address_space       = [var.address_space]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# ==============================================================================
# Subnets
# ==============================================================================

resource "azurerm_subnet" "adx" {
  name                 = "snet-adx"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.adx_subnet_prefix]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "aci" {
  name                 = "snet-aci"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aci_subnet_prefix]

  delegation {
    name = "aci-delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

# ==============================================================================
# Network Security Groups
# ==============================================================================

resource "azurerm_network_security_group" "adx" {
  name                = "nsg-adx"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-azure-services"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureCloud"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "aci" {
  name                = "nsg-aci"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-grafana-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# ==============================================================================
# NSG Associations
# ==============================================================================

resource "azurerm_subnet_network_security_group_association" "adx" {
  subnet_id                 = azurerm_subnet.adx.id
  network_security_group_id = azurerm_network_security_group.adx.id
}

resource "azurerm_subnet_network_security_group_association" "aci" {
  subnet_id                 = azurerm_subnet.aci.id
  network_security_group_id = azurerm_network_security_group.aci.id
}

# ==============================================================================
# Azure Bastion (Optional)
# ==============================================================================

resource "azurerm_public_ip" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "pip-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

resource "azurerm_bastion_host" "main" {
  count               = var.enable_bastion ? 1 : 0
  name                = "bastion-adx-poc"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = var.tags
}
