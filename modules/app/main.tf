resource "azurerm_resource_group" "app-rg" {
  name     = "app-rg"
  location = var.location
}

resource "random_string" "app_suffix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

///////////////////// linux app service //////////////////////
resource "azurerm_linux_web_app" "app-service" {
  name                = "ai-assistant-01"
  location            = var.location
  resource_group_name = azurerm_resource_group.app-rg.name
  service_plan_id     = azurerm_service_plan.app-service-plan.id
  virtual_network_subnet_id = var.subnet_ids[2]

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.12"
    }
    app_command_line = "gunicorn -w 2 -k uvicorn.workers.UvicornWorker main:app"
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    AZURE_OPENAI_ENDPOINT          = var.openai_endpoint
    AZURE_SEARCH_ENDPOINT          = var.search_endpoint
  }
}

///////////////////// app service plan //////////////////////
resource "azurerm_service_plan" "app-service-plan" {
  name                = "app-service-plan"
  location            = var.location
  resource_group_name = azurerm_resource_group.app-rg.name
  sku_name            = "P1v2"
  os_type             = "Linux"
}


/////////////////////     role assignment for web app //////////////////////
resource "azurerm_role_assignment" "app-service-openai-role-assignment" {
  principal_id         = azurerm_linux_web_app.app-service.identity[0].principal_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = var.cognitive_account_id
}

resource "azurerm_role_assignment" "app-service-search-role-assignment" {
  principal_id         = azurerm_linux_web_app.app-service.identity[0].principal_id
  role_definition_name = "Search Index Data Reader"
  scope                = var.search_service_id
}