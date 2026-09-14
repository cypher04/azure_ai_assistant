resource "azurerm_resource_group" "networking-rg" {
  name     = "networking-rg"
  location = var.location
}

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
  address_space       = [var.address_space[0]]
}

resource "azurerm_virtual_network" "ai-spoke-vnet" {
  name                = "ai-spoke-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
  address_space       = [var.address_space[1]]
}

resource "azurerm_virtual_network" "data-spoke-vnet" {
  name                = "data-spoke-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
  address_space       = [var.address_space[2]]
}

// subnet for hub virtual network
resource "azurerm_subnet" "hub-subnet" {
  name                 = "hub-subnet"
  resource_group_name  = azurerm_resource_group.networking-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = [var.subnet_prefixes["hub-subnet"]]
}

// subnet for AI spoke virtual network
resource "azurerm_subnet" "ai-spoke-subnet" {
  name                 = "ai-spoke-subnet"
  resource_group_name  = azurerm_resource_group.networking-rg.name
  virtual_network_name = azurerm_virtual_network.ai-spoke-vnet.name
  address_prefixes     = [var.subnet_prefixes["ai-spoke-subnet"]]
}

// subnet for data spoke virtual network
resource "azurerm_subnet" "data-spoke-subnet" {
  name                 = "data-spoke-subnet"
  resource_group_name  = azurerm_resource_group.networking-rg.name
  virtual_network_name = azurerm_virtual_network.data-spoke-vnet.name
  address_prefixes     = [var.subnet_prefixes["data-spoke-subnet"]]
}





/////////////////////// peer all three vnets
resource "azurerm_virtual_network_peering" "hub-to-ai-spoke" {
  name                      = "hub-to-ai-spoke"
  resource_group_name       = azurerm_resource_group.networking-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.ai-spoke-vnet.id
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "ai-spoke-to-hub" {
  name                      = "ai-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.networking-rg.name
  virtual_network_name      = azurerm_virtual_network.ai-spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "hub-to-data-spoke" {
  name                      = "hub-to-data-spoke"
  resource_group_name       = azurerm_resource_group.networking-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.data-spoke-vnet.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "data-spoke-to-hub" {
  name                      = "data-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.networking-rg.name
  virtual_network_name      = azurerm_virtual_network.data-spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "ai-spoke-to-data-spoke" {
  name                      = "ai-spoke-to-data-spoke"
  resource_group_name       = azurerm_resource_group.networking-rg.name
  virtual_network_name      = azurerm_virtual_network.ai-spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.data-spoke-vnet.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "data-spoke-to-ai-spoke" {
  name                      = "data-spoke-to-ai-spoke"
  resource_group_name       = azurerm_resource_group.networking-rg.name
  virtual_network_name      = azurerm_virtual_network.data-spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.ai-spoke-vnet.id
  allow_virtual_network_access = true
}




////////////////////// user defined route
resource "azurerm_route_table" "hub-route-table" {
  name                = "hub-route-table"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

#   route {
#     name                   = "hub-route"
#     address_prefix         = "0.0.0.0/0"
#     next_hop_type          = "Internet"
#   }


}

resource "azurerm_subnet_route_table_association" "hub-subnet-association" {
  subnet_id      = azurerm_subnet.hub-subnet.id
  route_table_id = azurerm_route_table.hub-route-table.id
}

// user defined route for AI spoke subnet to route traffic through hub virtual network
resource "azurerm_route_table" "ai-spoke-route-table" {
  name                = "ai-spoke-route-table"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

#   route {
#     name                   = "ai-spoke-route"
#     address_prefix         = "0.0.0.0/0"
#     next_hop_type          = "VirtualAppliance"
#     next_hop_in_ip_address = azurerm_subnet.hub-subnet.address_prefixes[0]
#   }
  

}

resource "azurerm_subnet_route_table_association" "ai-spoke-subnet-association" {
  subnet_id      = azurerm_subnet.ai-spoke-subnet.id
  route_table_id = azurerm_route_table.ai-spoke-route-table.id
}

// user defined route for data spoke subnet
resource "azurerm_route_table" "data-spoke-route-table" {
  name                = "data-spoke-route-table"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

#   route {
#     name                   = "data-spoke-route"
#     address_prefix         = "0.0.0.0/0"
#     next_hop_type          = "VirtualAppliance"
#     next_hop_in_ip_address = azurerm_subnet.hub-subnet.address_prefixes[0]
#   }

}

resource "azurerm_subnet_route_table_association" "data-spoke-subnet-association" {
  subnet_id      = azurerm_subnet.data-spoke-subnet.id
  route_table_id = azurerm_route_table.data-spoke-route-table.id
}


/////////// public IP for firewall
# resource "azurerm_public_ip" "networking-firewall-pip" {
#   name                = "networking-firewall-pip"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.networking-rg.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

////////// firewall

# resource "azurerm_firewall" "networking-firewall" {
#   name                = "networking-firewall"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.networking-rg.name
#   sku_name            = "AZFW_VNet"
#   sku_tier            = "Standard"

#   ip_configuration {
#     name                 = "networking-firewall-ip-configuration"
#     subnet_id            = azurerm_subnet.hub-subnet.id
#     public_ip_address_id = azurerm_public_ip.networking-firewall-pip.id
#   }
# }


////////////////// network security group for hub subnet
resource "azurerm_network_security_group" "hub-subnet-nsg" {
  name                = "hub-subnet-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

  security_rule {
    name                       = "allow-internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "hub-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.hub-subnet.id
  network_security_group_id = azurerm_network_security_group.hub-subnet-nsg.id
}

// network security group for data-spoke subnet
resource "azurerm_network_security_group" "data-spoke-subnet-nsg" {
  name                = "data-spoke-subnet-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

  security_rule {
    name                       = "allow-internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "data-spoke-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.data-spoke-subnet.id
  network_security_group_id = azurerm_network_security_group.data-spoke-subnet-nsg.id
}

// network security group for ai-spoke subnet
resource "azurerm_network_security_group" "ai-spoke-subnet-nsg" {
  name                = "ai-spoke-subnet-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

  security_rule {
    name                       = "allow-internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "ai-spoke-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.ai-spoke-subnet.id
  network_security_group_id = azurerm_network_security_group.ai-spoke-subnet-nsg.id
}


