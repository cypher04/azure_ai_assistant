
terraform {
  required_providers {

    azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 4.80.0"
        }

    azuread = {
        source  = "hashicorp/azuread"
        version = "~> 3.9.0"
        }

    gitlab = {
        source  = "gitlabhq/gitlab"
        version = "~> 19.3.0"
        }
  }
}


provider "azurerm" {
  features {}
}

provider "azuread" {
  tenant_id = var.tenant_id
}

provider "gitlab" {
  token = var.gitlab_token
}
