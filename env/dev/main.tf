data "azurerm_client_config" "current" {
}

module "networking" {
  source               = "../../modules/networking"
  location             = var.location
  subnet_prefixes      = var.subnet_prefixes
  address_space        = var.address_space
  cognitive_account_id = module.compute.cognitive_account_id
  ai_storage_id        = module.database.ai_storage_id
  web_app_id           = module.app.web_app_id
}

module "compute" {
  source        = "../../modules/compute"
  ai_storage_id = module.database.ai_storage_id
  location      = var.location
}

module "database" {
  source   = "../../modules/database"
  location = var.location
}

module "app" {
  source               = "../../modules/app"
  location             = var.location
  cognitive_account_id = module.compute.cognitive_account_id
  openai_endpoint      = module.compute.openai_endpoint
  search_endpoint      = module.compute.search_endpoint
  search_service_id    = module.compute.search_service_id
  app_location         = var.app_location
}

resource "azurerm_role_assignment" "ingest-search-service-role-assignment" {
  principal_id         = var.ingest_principal_id
  role_definition_name = "Search Service Contributor"
  scope                = module.compute.search_service_id
}

resource "azurerm_role_assignment" "ingest-storage-role-assignment" {
  principal_id         = var.ingest_principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.database.ai_storage_id
}

resource "azurerm_role_assignment" "ingest-search-role-assignment" {
  principal_id         = var.ingest_principal_id
  role_definition_name = "Search Index Data Contributor"
  scope                = module.compute.search_service_id
}

resource "azurerm_role_assignment" "ingest-openai-role-assignment" {
  principal_id         = var.ingest_principal_id
  role_definition_name = "Cognitive Services OpenAI User"
  scope                = module.compute.cognitive_account_id
}
