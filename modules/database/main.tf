resource "azurerm_resource_group" "database-rg" {
  name     = "database-rg"
  location = var.location
}
