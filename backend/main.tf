resource "azurerm_resource_group" "state_rg" {
  name     = "${var.project_name}-rg"
  location = var.location
}

data "azurerm_client_config" "current" {

}

resource "azurerm_storage_account" "state_storage" {
  name                     = "${var.project_name}state"
  resource_group_name      = azurerm_resource_group.state_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

    lifecycle {
        prevent_destroy = true
    }

    min_tls_version            = "TLS1_2"
    https_traffic_only_enabled = true

    blob_properties {
      versioning_enabled = true

      delete_retention_policy {
        days = 30
      }
    }
}

resource "azurerm_storage_container" "state_container" {
    name                  = "tfstate"
    container_access_type = "private"
    storage_account_id    = azurerm_storage_account.state_storage.id
    }


variable "project_name" {
  description = "name of the project"
  type = string
}

variable "environment" {
  description = "deployment environment (e.g., dev, prod)"
  type = string
}

variable "location" {
  description = "name of the location"
  type = string
}

