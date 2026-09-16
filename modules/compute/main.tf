resource "azurerm_resource_group" "compute-rg" {
  name     = "compute-rg"
  location = var.location
}

