resource "azurerm_resource_group" "database-rg" {
  name     = "database-rg"
  location = var.location
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

///////////////////// storage account for ai //////////////////////
resource "azurerm_storage_account" "ai_storage" {
  name                          = "aistorage${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.database-rg.name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  https_traffic_only_enabled    = true
  public_network_access_enabled = false
}

resource "azurerm_storage_container" "documents" {
  name                  = "documents"
  storage_account_id    = azurerm_storage_account.ai_storage.id
  container_access_type = "private"

}

resource "azurerm_storage_container" "processed" {
  name                  = "processed"
  storage_account_id    = azurerm_storage_account.ai_storage.id
  container_access_type = "private"
}