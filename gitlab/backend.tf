terraform {
  backend "azurerm" {
    use_azuread_auth = true
    use_oidc = true
    resource_group_name  = "azure0ai0assistant-rg"
    storage_account_name = "azure0ai0assistantstate"
    container_name       = "tfstate"
    key                  = "gitlab-ai-terraform.tfstate"
  }
}