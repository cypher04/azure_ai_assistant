terraform {
  backend "azurerm" {
    resource_group_name  = "azure0ai0assistant-rg"
    storage_account_name = "azure0ai0assistantstate"
    container_name       = "tfstate"
    key                  = "ai-terraform.tfstate"
  }
}