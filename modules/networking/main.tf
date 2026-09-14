resource "azurerm_resource_group" "networking-rg" {
  name     = "networking-rg"
  location = var.location
}

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
  address_space       = var.address_space
}

resource "azurerm_virtual_network" "ai-spoke-vnet" {
  name                = "ai-spoke-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
  address_space       = var.address_space
}

resource "azurerm_virtual_network" "data-spoke-vnet" {
  name                = "data-spoke-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
  address_space       = var.address_space
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

////////////////////// user defined route
resource "azurerm_route_table" "hub-route-table" {
  name                = "hub-route-table"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name

  


}

resource "azurerm_subnet_route_table_association" "hub-subnet-association" {
  subnet_id      = azurerm_subnet.hub-subnet.id
  route_table_id = azurerm_route_table.hub-route-table.id
}

// user defined route for AI spoke subnet
resource "azurerm_route_table" "ai-spoke-route-table" {
  name                = "ai-spoke-route-table"
  location            = var.location
  resource_group_name = azurerm_resource_group.networking-rg.name
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
}

resource "azurerm_subnet_route_table_association" "data-spoke-subnet-association" {
  subnet_id      = azurerm_subnet.data-spoke-subnet.id
  route_table_id = azurerm_route_table.data-spoke-route-table.id
}


# /////////// public IP for firewall
# resource "azurerm_public_ip" "networking-firewall-pip" {
#   name                = "networking-firewall-pip"
#   location            = var.location
#   resource_group_name = azurerm_resource_group.networking-rg.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# ////////// firewall

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
