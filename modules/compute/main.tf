resource "azurerm_resource_group" "compute-rg" {
  name     = "compute-rg"
  location = var.location
}

resource "random_string" "cognitive_account_suffix" {
  length  = 6
  upper   = false
  special = false
}


///////////////////// cognitive account //////////////////////
resource "azurerm_cognitive_account" "cognitive-account" {
  name                       = "aifoundry${random_string.cognitive_account_suffix.result}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.compute-rg.name
  kind                       = "AIServices"
  sku_name                   = "S0"
  custom_subdomain_name      = "aifoundry${random_string.cognitive_account_suffix.result}"
  project_management_enabled = true


  identity {
    type = "SystemAssigned"
  }
}

///////////////////// cognitive project //////////////////////
resource "azurerm_cognitive_account_project" "cognitive-project" {
  name                 = "cognitive-project"
  location             = var.location
  cognitive_account_id = azurerm_cognitive_account.cognitive-account.id

  identity {
    type = "SystemAssigned"
  }
}

///////////////////// cognitive deployment //////////////////////
resource "azurerm_cognitive_deployment" "cognitive-deployment" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.cognitive-account.id
  rai_policy_name      = azurerm_cognitive_account_rai_policy.cognitive-rai-policy.name
  sku {
    name     = "GlobalStandard"
    capacity = 5
  }

  model {
    name    = "gpt-4o"
    format  = "OpenAI"
    version = "2024-11-20"
  }


  depends_on = [
    azurerm_cognitive_account.cognitive-account
  ]
}

///////////////////// cognitive account rai policy //////////////////////
resource "azurerm_cognitive_account_rai_policy" "cognitive-rai-policy" {
  cognitive_account_id = azurerm_cognitive_account.cognitive-account.id
  name                 = "cognitive-rai-policy"
  base_policy_name     = "Microsoft.Default"

  content_filter {
    name               = "Hate"
    filter_enabled     = true
    block_enabled      = true
    severity_threshold = "High"
    source             = "Prompt"
  }
}

/////////////////////    search service    //////////////////////
resource "azurerm_search_service" "search-service" {
  name                          = "search${random_string.search_service_suffix.result}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.compute-rg.name
  sku                           = "standard"
  semantic_search_sku           = "free"
  local_authentication_enabled  = false
  public_network_access_enabled = true
}

resource "random_string" "search_service_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}


///////////////////// search private link service //////////////////////
resource "azurerm_search_shared_private_link_service" "search-api-key" {
  search_service_id = azurerm_search_service.search-service.id
  name               = "search-private-link-service"
  subresource_name    = "blob"
  target_resource_id   = var.ai_storage_id
}